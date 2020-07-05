//
//  File.swift
//
//
//  Created by Kevin Carter on 6/25/20.
//

import Foundation

import Shout

class ExecuteSSH: Execution {
    var ssh: SSH?
    var server: String = "localhost"
    var port: Int32 = 22
    var name: String = "localhost"
    var key: String? = nil

    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        super.init(cliParameters: cliParameters, processParams: processParams)
        self.workdir = "/"
        self.workdirURL = URL(fileURLWithPath: workdir)
    }

    override func connect() throws {
        let cssh = try SSH(host: self.server, port: self.port)
        cssh.ptyType = .vanilla
        if let privatekey = self.key {
            logger.info("Connecting to \(String(describing: self.target ?? self.server)) using key based authentication")
            try cssh.authenticate(username: self.user, privateKey: privatekey)
        } else {
            logger.info("Connecting to \(String(describing: self.target ?? self.server)) using agent based authentication")
            try cssh.authenticateByAgent(username: self.user)
        }
        self.ssh = cssh
    }

    override func probe() throws {
        logger.info("Running remote system probe")
        //    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
        //    TARGETOS - OS component of TARGETPLATFORM
        //    TARGETARCH - architecture component of TARGETPLATFORM
        let unameLookup = ["x86_64": "amd64", "armv7l": "arm/v7", "armv8l": "arm/v8"]
        let output = try self.runReturn(execute: "uname -ms; systemctl --version")
        let outputComponents = output.components(separatedBy: "\n")
        let targetVars = outputComponents.first!.components(separatedBy: " ")
        let kernel = targetVars.first!.strip
        let archRaw = targetVars.last!.strip
        let arch = unameLookup[archRaw] ?? "unknown"
        let systemd = outputComponents[1].components(separatedBy: " ")
        self.environment["TARGETOS"] = kernel
        self.environment["TARGETARCH"] = arch
        self.environment["TARGETPLATFORM"] = "\(kernel)/\(arch)"
        self.environment["SYSTEMD_VERSION"] = String(describing: systemd.last!.strip)
    }

    override func copyRun(toUrl: URL, fromUrl: URL) throws -> String {
        try self.ssh!.sendFile(localURL: fromUrl, remotePath: toUrl.path)
        return toUrl.path
    }

    override func move(fromPath: String, toPath: String) throws {
        try self.run(execute: "mv \(fromPath) \(toPath)")
    }

    override func run(execute: String) throws {
        _ = try self.runReturn(execute: execute)
    }

    func prepareExec(execute: String) -> String {
        let preparedExec = self.execPosixString(command: execute)
        var envVars: [String] = []
        for (key, value) in self.environment {
            envVars.append("export \(key)=\(value);")
        }
        return self.posixEncoder(item: envVars.joined(separator: " ") + " " + preparedExec)
    }

    override func runReturn(execute: String) throws -> String {
        // NOTE This is not ideal, I wishthere was a better way to leverage an
        // environment setup prior to executing a command which didn't require
        // server side configuration, however, it does so here we are.
        let preparedCommand = self.prepareExec(execute: execute)
        let (status, output) = try self.ssh!.capture(preparedCommand)
        if status != 0 {
            throw RouterError.failedExecution(message: "FAILED execution: \(output)")
        }
        return output
    }

    override func mkdir(workdirURL: URL) throws {
        try self.run(execute: "mkdir -p \(workdirURL.path)")
    }

    override func entrypointStart(entrypoint: String) throws {
        if self.environment.keys.contains("SYSTEMD_VERSION") {
            try super.entrypointStart(entrypoint: entrypoint)
        } else {
            throw RouterError.notImplemented(
                message: """
                         Service templating is not currently supported on non-linux operating systems without systemd.
                         """
            )
        }
    }
}

class ExecuteSSHVia: ExecuteSSH {
    var sshConnectionString: String
    var scpConnectionString: String
    var connectionArgs: [String] = ["-o ControlPersist=600"]
    var sshCommand: [String]?
    var scpCommand: [String]?
    let controlPath: URL

    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        self.sshConnectionString = "/usr/bin/ssh"
        self.scpConnectionString = "/usr/bin/scp"
        self.controlPath = URL(fileURLWithPath: NSTemporaryDirectory())

        super.init(cliParameters: cliParameters, processParams: processParams)
        self.connectionArgs.append("-o ControlPath=\"\(controlPath.path)/.ssh/%h\"")
        self.connectionArgs.append("-F \(self.processParams.octaheSshConfigFile!.path)")
        if let privatekey = self.key {
            self.connectionArgs.append("-i " + privatekey)
        }
    }

    override func connect() throws {
        logger.info("Connecting to \(String(describing: self.target)) using local ssh.")
        try self.localMkdir(workdirURL: controlPath.appendingPathComponent(".ssh/sockets", isDirectory: true))
        let sshArgs = self.connectionArgs.joined(separator: " ")
        self.sshCommand = [
            self.sshConnectionString,
            sshArgs,
            "-t",
            "-n",
            self.name.sha1
        ]
        self.scpCommand = [self.scpConnectionString, sshArgs, "-3"]
    }

    override func copyRun(toUrl: URL, fromUrl: URL) throws -> String {
        func scriptExec(execArgs: [String]) throws {
            let execScript = try self.localWriteTemp(
                content: execArgs.joined(separator: " ")
            )
            defer {
                try? FileManager.default.removeItem(at: execScript)
            }
            _ = try self.localExec(commandArgs: ["/bin/sh", execScript.path])
        }
        var scpExecute = self.scpCommand
        scpExecute?.append(fromUrl.path)
        scpExecute?.append("\(self.name.sha1):\(toUrl.path)")
        try scriptExec(execArgs: scpExecute!)
        return toUrl.path
    }

    override func runReturn(execute: String) throws -> String {
        let execTask = self.prepareExec(execute: execute)
        let execScript: URL
        execScript = try self.localWriteTemp(
            content: self.sshCommand!.joined(separator: " ") + " " + self.posixEncoder(item: execTask).quote
        )
        let execArray = ["/bin/sh", execScript.path]
        defer {
            try? FileManager.default.removeItem(at: execScript)
        }
        return try self.localExec(commandArgs: execArray)
    }
}
