//
//  File.swift
//  
//
//  Created by Kevin Carter on 6/25/20.
//

import Foundation

class ExecuteLocal: Execution {
    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        super.init(cliParameters: cliParameters, processParams: processParams)
    }

    override func probe() throws {
        for (key, value) in processParams.octaheArgs {
            let targetKey = key.replacingOccurrences(of: "BUILD", with: "TARGET")
            self.environment[targetKey] = value
        }
        self.environment["PATH"] = ProcessInfo.processInfo.environment["PATH"]
    }

    override func chown(perms: String?, path: String) throws {
        if let chownSettings = perms {
            let ownerGroup = chownSettings.components(separatedBy: ":")
            var attributes = [FileAttributeKey.ownerAccountName: ownerGroup.first]
            if ownerGroup.first != ownerGroup.last {
                attributes[FileAttributeKey.ownerAccountName] = ownerGroup.last
            }
            try FileManager.default.setAttributes(attributes as [FileAttributeKey: Any], ofItemAtPath: path)
        }
    }

    override func copyRun(toUrl: URL, fromUrl: URL, toFile: URL) throws -> String {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: toUrl.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                try FileManager.default.removeItem(at: toUrl)
            }
        }
        if FileManager.default.fileExists(atPath: toFile.path) {
            try FileManager.default.removeItem(at: toFile)
        }
        do {
            try FileManager.default.copyItem(at: fromUrl, to: toUrl)
            return toUrl.path
        } catch {
            try FileManager.default.copyItem(at: fromUrl, to: toFile)
            return toFile.path
        }
    }

    override func copy(base: URL, copyTo: String, fromFiles: [String], chown: String? = nil) throws {
        let toUrl = URL(fileURLWithPath: copyTo)
        for fromUrl in try self.indexFiles(basePath: base, fromFiles: fromFiles) {
            let copyFile = try self.copyRun(
                toUrl: toUrl,
                fromUrl: fromUrl,
                toFile: toUrl.appendingPathComponent(fromUrl.lastPathComponent)
            )
            try self.chown(perms: chown, path: copyFile)
        }
    }

    override func run(execute: String) throws {
        _ = try self.runReturn(execute: execute)
    }

    override func runReturn(execute: String) throws -> String {
        let execTask = execString(command: execute)

        var launchArgs = (self.shell).components(separatedBy: " ")
        launchArgs.append(execTask)

        if !FileManager.default.fileExists(atPath: workdirURL.path) {
            try self.mkdir(workdirURL: workdirURL)
        }

        FileManager.default.changeCurrentDirectoryPath(workdir)
        let task = Process()
        let pipe = Pipe()
        task.environment = self.environment
        task.executableURL = URL(fileURLWithPath: launchArgs.removeFirst())
        task.arguments = launchArgs
        task.standardError = FileHandle.nullDevice
        task.standardOutput = pipe
        pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw RouterError.failedExecution(message: "FAILED: \(execute) \(task.terminationStatus) \(task.terminationStatus)")
        }
        let output = pipe.fileHandleForReading.availableData
        return String(data: output, encoding: String.Encoding.utf8)!
    }

    override func mkdir(workdirURL: URL) throws {
        try FileManager.default.createDirectory(
            at: workdirURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    override func serviceTemplate(entrypoint: String) throws {
        guard FileManager.default.fileExists(atPath: "/etc/systemd/system") else {
            throw RouterError.notImplemented(
                message: """
                         Service templating is currently only supported systems with systemd.
                         """
            )
        }
        try super.serviceTemplate(entrypoint: entrypoint)
    }
}
