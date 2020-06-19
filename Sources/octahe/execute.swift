//
//  execute.swift
//  
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation


class NodeOperations {
    let maxConcurrentOperationCount: Int

    init(connectionQuota: Int) {
        maxConcurrentOperationCount = connectionQuota
    }

    lazy var nodesInProgress: [IndexPath: Operation] = [:]
    lazy var nodeQueue: OperationQueue = {
    var queue = OperationQueue()
        queue.name = "Node queue"
        queue.maxConcurrentOperationCount = self.maxConcurrentOperationCount
        return queue
    }()
}


class TaskOperations {
    lazy var tasksInProgress: [IndexPath: Operation] = [:]
    lazy var taskQueue: OperationQueue = {
    var queue = OperationQueue()
        queue.name = "Task queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}


class Execution {
    let cliParams: octaheCLI.Options
    let processParams: ConfigParse
    var steps: Int = 0
    var statusLine: String = ""
    var shell: String = "/bin/sh -c"
    var escallation: String?  // TODO(): We need a means to escallate our privledges and supply a password when invoked.
    var environment: Dictionary<String, String> = [:]
    var server: String = "localhost"
    var port: String = "22"
    var user: String = NSUserName()

    init(cliParameters: octaheCLI.Options, processParams: ConfigParse) {
        self.cliParams = cliParameters
        self.processParams = processParams
    }

    func connect(target: String) throws {
        preconditionFailure("This method must be overridden")
    }

    func probe() {
        // TODO(cloudnull): The follow args need to be rendered from the target and added to a CONSTANT
        // Sourced from remote target at runtime:
        //    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
        //    TARGETOS - OS component of TARGETPLATFORM
        //    TARGETARCH - architecture component of TARGETPLATFORM
        //    TARGETVARIANT - variant component of TARGETPLATFORM
        preconditionFailure("This method must be overridden")
    }

    func close() {
        preconditionFailure("This method must be overridden")
    }

    func run(execute: String) throws {
        preconditionFailure("This method must be overridden")
    }

    func copy(base: URL, to: String, fromFiles: [String]) throws {
        preconditionFailure("This method must be overridden")
    }

    func serviceTemplate(command: String?, entrypoint: String?, entrypointOptions: typeEntrypointOptions) throws {
        // Generate a local template, and transfer it to the remote host
        guard !FileManager.default.fileExists(atPath: "/etc/systemd/system") else {
            throw RouterError.NotImplemented(
                message: """
                         Servive templating is not currently supported on non-linux operating systems without systemd.
                         """
            )
        }
        let baseUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let hashedFile = entrypoint ?? command
        if hashedFile != nil {
            let serviceFile = "octahe-" + hashedFile!.md5 + ".service"
            try copy(
                base: baseUrl,
                to: "/etc/systemd/system/" + serviceFile,
                fromFiles: ["/tmp/" + serviceFile]  // This should be changed to the base path of the required template.
            )
        }
    }
}


class ExecuteLocal: Execution {
    override func probe() {
        for (key, value) in PlatformArgs() {
            let targetKey = key.replacingOccurrences(of: "BUILD", with: "TARGET")
            self.environment[targetKey] = value
        }
    }

    override func copy(base: URL, to: String, fromFiles: [String]) throws {
        let toUrl = URL(fileURLWithPath: to)
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

    private func localExec(command: String) throws {
        var launchArgs = (self.shell).components(separatedBy: " ")
        launchArgs.append(command)
        let task = Process()
        task.environment = self.environment
        task.launchPath = launchArgs.removeFirst()
        task.arguments = launchArgs
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.launch()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            throw RouterError.FailedExecution(message: "FAILED: \(command)")
        }
    }
}


class ExecuteEcho: ExecuteLocal {
    override func run(execute: String) throws {
        print(execute)
    }

    override func copy(base: URL, to: String, fromFiles: [String]) throws {
        for file in fromFiles {
            let fromUrl = base.appendingPathComponent(file)
            print(fromUrl.path, to)
        }
    }
}


class ExecuteSSH: ExecuteEcho {
    // Currently this does nothing, when this is ready to do something, it should subclass Execute
}
