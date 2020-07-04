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

    override func copyRun(toUrl: URL, fromUrl: URL) throws -> String {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: toUrl.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                try FileManager.default.removeItem(at: toUrl)
            }
        }
        try FileManager.default.copyItem(at: fromUrl, to: toUrl)
        return toUrl.path
    }

    override func copy(base: URL, copyTo: String, fromFiles: [String], chown: String? = nil) throws {
        let toUrl = URL(fileURLWithPath: copyTo)
        for fromUrl in try self.indexFiles(basePath: base, fromFiles: fromFiles) {
            let copyFile = try self.copyRun(
                toUrl: toUrl,
                fromUrl: fromUrl
            )
            try self.chown(perms: chown, path: copyFile)
        }
    }

    override func runReturn(execute: String) throws -> String {
        if !FileManager.default.fileExists(atPath: workdirURL.path) {
            try self.localMkdir(workdirURL: workdirURL)
        }
        FileManager.default.changeCurrentDirectoryPath(workdir)
        return try self.localExecReturn(execute: execute)
    }

    override func move(fromPath: String, toPath: String) throws {
        try FileManager.default.moveItem(atPath: fromPath, toPath: toPath)
    }

    override func run(execute: String) throws {
        _ = try self.runReturn(execute: execute)
    }

    override func mkdir(workdirURL: URL) throws {
        try localMkdir(workdirURL: workdirURL)
    }

    override func entrypointStart(entrypoint: String) throws {
        guard FileManager.default.fileExists(atPath: "/etc/systemd/system") else {
            throw RouterError.notImplemented(
                message: """
                         Service templating is currently only supported systems with systemd.
                         """
            )
        }
        try super.entrypointStart(entrypoint: entrypoint)
    }
}
