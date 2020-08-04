//
//  File.swift
//
//
//  Created by Kevin Carter on 6/25/20.
//

import Foundation

class ExecuteSSH: Execution {
    var server: String = "localhost"
    var port: Int32 = 22
    var name: String = "localhost"
    var key: String?
    var sshConnectionString: String = "/usr/bin/ssh"
    var scpConnectionString: String = "/usr/bin/scp"
    var connectionArgs: [String] = []
    var sshCommand: [String]?
    var scpCommand: [String]?

    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        super.init(cliParameters: cliParameters, processParams: processParams)

        self.workdir = "/"
        self.workdirURL = URL(fileURLWithPath: workdir)
        if let sshConfig = self.processParams.octaheSshConfigFile {
            self.connectionArgs.append("-F \(String(describing: sshConfig.path).quote)")
        }
        if let privatekey = self.key {
            self.connectionArgs.append("-i " + privatekey)
        }
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

    override func move(fromPath: String, toPath: String) throws {
        try self.run(execute: "mv \(fromPath) \(toPath)")
    }

    override func run(execute: String) throws {
        _ = try self.runReturn(execute: execute)
    }

    private func prepareExec(execute: String) -> String {
        return self.posixEncoder(item: self.execPosixString(command: execute))
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

    override func connect() throws {
        logger.info("Connecting to \(String(describing: self.target)) using local ssh.")
        let sshArgs = self.connectionArgs.joined(separator: " ")
        self.sshCommand = [
            self.sshConnectionString,
            sshArgs,
            "-n",
            self.name.sha1
        ]
        self.scpCommand = [self.scpConnectionString, sshArgs, "-3"]
    }

    override func copyRun(toUrl: URL, fromUrl: URL) throws -> String {
        var scpExecute = self.scpCommand
        scpExecute?.append(fromUrl.path)
        scpExecute?.append("\(self.name.sha1):\(toUrl.path)")
        _ = try self.localExec(commandArgs: ["/bin/sh", "-c", scpExecute!.joined(separator: " ")])
        return toUrl.path
    }

    override func runReturn(execute: String) throws -> String {
        var sshRunner = self.sshCommand!
        sshRunner.append(self.prepareExec(execute: "\(execute) 1>/dev/null").escapeQuote)
        return try self.localExec(commandArgs: ["/bin/sh", "-c", sshRunner.joined(separator: " ")])
    }
}
