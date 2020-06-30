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

    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        super.init(cliParameters: cliParameters, processParams: processParams)
        self.workdir = "/"
        self.workdirURL = URL(fileURLWithPath: workdir)
    }

    override func connect() throws {
        let cssh = try SSH(host: self.server, port: self.port)
        cssh.ptyType = .vanilla
        if let privatekey = self.cliParams.connectionKey {
            try cssh.authenticate(username: self.user, privateKey: privatekey)
        } else {
            try cssh.authenticateByAgent(username: self.user)
        }
        self.ssh = cssh
    }

    override func probe() throws {
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

    override func copyRun(toUrl: URL, fromUrl: URL, toFile: URL) throws -> String {
        do {
            try self.ssh!.sendFile(localURL: fromUrl, remotePath: toUrl.path)
            return toUrl.path
        } catch {
            try self.ssh!.sendFile(localURL: fromUrl, remotePath: toFile.path)
            return toFile.path
        }
    }

    override func chown(perms: String?, path: String) throws {
        if let chownSettings = perms {
            try self.run(execute: "chown \(chownSettings) \(path)")
        }
    }

    override func run(execute: String) throws {
        _ = try self.runReturn(execute: execute)
    }

    func prepareExec(execute: String) -> String {
        let preparedExec = self.execString(command: execute)
        var envVars: [String] = []
        for (key, value) in self.environment {
            envVars.append("export \(key)=\(value);")
        }
        return envVars.joined(separator: " ") + " " + preparedExec
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

    override func serviceTemplate(entrypoint: String) throws {
        if self.environment.keys.contains("SYSTEMD_VERSION") {
            try super.serviceTemplate(entrypoint: entrypoint)
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
    var connectionArgs: [String]
    var sshCommand: [String]?
    var scpCommand: [String]?
    let controlPath: URL

    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        self.sshConnectionString = "/usr/bin/ssh"
        self.scpConnectionString = "/usr/bin/scp"
        self.controlPath = URL(fileURLWithPath: NSTemporaryDirectory())
        self.connectionArgs = [
            "-o GlobalKnownHostsFile=/dev/null",
            "-o UserKnownHostsFile=/dev/null",
            "-o StrictHostKeyChecking=no",
            "-o Compression=no",
            "-o TCPKeepAlive=yes",
            "-o VerifyHostKeyDNS=no",
            "-o ForwardX11=no",
            "-o ControlMaster=auto",
            "-o ControlPath=\"\(controlPath.path)/.ssh/%h\"",
            "-o ControlPersist=600"
        ]
        super.init(cliParameters: cliParameters, processParams: processParams)
        if let privatekey = self.cliParams.connectionKey {
            self.connectionArgs.append("-i " + privatekey)
        }
    }

    override func connect() throws {
        try self.localMkdir(workdirURL: controlPath.appendingPathComponent(".ssh/sockets", isDirectory: true))
        let sshArgs = self.connectionArgs.joined(separator: " ")
        self.sshCommand = [
            self.sshConnectionString,
            sshArgs,
            "-t",
            "-n",
            "-p \(self.port)",
            "\(self.user)@\(self.server)"
        ]
        self.scpCommand = [self.scpConnectionString, sshArgs, "-3", "-q", "-P \(self.port)"]
    }

    override func copyRun(toUrl: URL, fromUrl: URL, toFile: URL) throws -> String {
        func scriptExec(execArgs: [String]) throws {
            let execScript = try self.localWriteTemp(
                content: execArgs.joined(separator: " ")
            )
            defer {
                try? FileManager.default.removeItem(at: execScript)
            }
            _ = try self.localExec(commandArgs: ["/bin/sh", execScript.path])
        }
        do {
            var scpExecute = self.scpCommand
            scpExecute?.append(fromUrl.path)
            scpExecute?.append("\(self.user)@\(self.server):\(toFile.path)")
            try scriptExec(execArgs: scpExecute!)
            return toFile.path
        } catch {
            var scpExecute = self.scpCommand
            scpExecute?.append(fromUrl.path)
            scpExecute?.append("\(self.user)@\(self.server):\(toUrl.path)")
            try scriptExec(execArgs: scpExecute!)
            return toUrl.path
        }
    }

    override func runReturn(execute: String) throws -> String {
        let execTask = self.prepareExec(execute: execute).b64encode
        let execScript: URL
        execScript = try self.localWriteTemp(
            content: self.sshCommand!.joined(separator: " ") + " 'printf \(execTask) | base64 --decode | sh'"
        )
        let execArray = ["/bin/sh", execScript.path]
        defer {
            try? FileManager.default.removeItem(at: execScript)
        }
        return try self.localExec(commandArgs: execArray)
    }
}
