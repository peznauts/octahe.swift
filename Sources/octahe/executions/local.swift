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

    override func copy(base: URL, copyTo: String, fromFiles: [String]) throws {
        let toUrl = URL(fileURLWithPath: copyTo)
        var isDir: ObjCBool = false
        for file in fromFiles {
            let fromUrl = base.appendingPathComponent(file)
            let toFile = toUrl.appendingPathComponent(fromUrl.lastPathComponent)
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
            } catch {
                try FileManager.default.copyItem(at: fromUrl, to: toFile)
            }
        }
    }

    override func run(execute: String) throws {
        try localExec(command: execute)
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

    private func localExec(command: String) throws {
        let execTask = execString(command: command)

        var launchArgs = (self.shell).components(separatedBy: " ")
        launchArgs.append(execTask)

        if !FileManager.default.fileExists(atPath: workdirURL.path) {
            try FileManager.default.createDirectory(
                at: workdirURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        FileManager.default.changeCurrentDirectoryPath(workdir)
        let task = Process()
        task.environment = self.environment
        task.launchPath = launchArgs.removeFirst()
        task.arguments = launchArgs
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw RouterError.failedExecution(message: "FAILED: \(command)")
        }
    }
}
