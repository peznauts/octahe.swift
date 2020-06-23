//
//  execute.swift
//  
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

import Shout


class Execution {
    let cliParams: octaheCLI.Options
    let processParams: ConfigParse
    var steps: Int = 0
    var shell: String = "/bin/sh -c"
    var escallation: String?  // TODO(): We need a means to escallate our privledges and supply a password when invoked.
    var environment: Dictionary<String, String> = [:]
    var execUser: String?
    var execGroup: String?
    var server: String = "localhost"
    var port: String = "22"
    var user: String = NSUserName()
    var escalate: String?
    var escalatePassword: String?
    var workdir: String = FileManager.default.currentDirectoryPath
    var workdirURL: URL
    var target: String?
    var healthcheck: String?
    var command: String?
    var stopsignal: String?
    var documentation: [Dictionary<String, String>] = [["item": "https://github.com/peznauts/octahe.swift"]]
    var ssh: SSH?

    init(cliParameters: octaheCLI.Options, processParams: ConfigParse) {
        self.cliParams = cliParameters
        self.processParams = processParams
        self.workdirURL = URL(fileURLWithPath: workdir)
    }

    func connect() throws -> SSH {
        preconditionFailure("This method must be overridden")
    }

    func probe() throws {
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

    func expose(nat: Int?, port: Int, proto: String?) throws {
        let port = port
        let proto = proto ?? "tcp"
        let commandCreate: String
        let commandDelete: String
        if let natPort = nat {
            commandCreate = "iptables -t nat -D PREROUTING -p \(proto) --dport \(port) -j REDIRECT --to-port \(natPort)"
            commandDelete = "iptables -t nat -A PREROUTING -p \(proto) --dport \(port) -j REDIRECT --to-port \(natPort)"
        } else {
            commandCreate = "iptables -A INPUT -p \(proto) -m \(proto) --dport \(port) -j ACCEPT"
            commandDelete = "iptables -D INPUT -p \(proto) -m \(proto) --dport \(port) -j ACCEPT"
        }
        try run(execute: "\(commandDelete) &> /dev/null; \(commandCreate)")
    }

    private func optionFormat(options: Dictionary<String, String>) -> [Dictionary<String, String>] {
        var items:[Dictionary<String, String>]  = []
        for (key, value) in options {
            switch key {
                case "ESCALATEPASSWORD":
                    logger.debug("filtering ESCALATEPASSWORD from service options")
                case _ where key.contains("BUILD"):
                    logger.debug("filtering BUILD* from service options")
                default:
                    items.append(["item": "\(key)=\(value)"])
            }
        }
        return items
    }

    func serviceTemplate(entrypoint: String) throws {
        // Generate a local template, and transfer it to the remote host
        guard !FileManager.default.fileExists(atPath: "/etc/systemd/system") else {
            throw RouterError.NotImplemented(
                message: """
                         Servive templating is not currently supported on non-linux operating systems without systemd.
                         """
            )
        }
        let serviceFile = "octahe-" + entrypoint.md5 + ".service"
        var serviceData: [String: Any] = ["user": self.user, "service_command": entrypoint, "shell": self.shell]

        if self.documentation.count > 0 {
            serviceData["documentation"] = self.documentation
        }
        if self.environment.count > 0 {
            serviceData["environment"] = optionFormat(options: self.environment)
        }
        if let group = self.execGroup {
            serviceData["group"] = group
        }
        if let sigKill = self.stopsignal {
            serviceData["kill_signal"] = sigKill
        }
        if self.workdir != FileManager.default.currentDirectoryPath {
            serviceData["workdir"] = self.workdir
        }
        let serviceRendered = try systemdRender(data: serviceData)
        if self.cliParams.dryRun {
            print("\n***** Service file *****\n\(serviceRendered)\n*************************\n")
        }
        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempService = tempUrl.appendingPathComponent("\(serviceFile)")
        if !FileManager.default.fileExists(atPath: tempService.path) {
            defer {
                try! FileManager.default.removeItem(at: tempService)
            }
            try serviceRendered.write(to: tempService, atomically: true, encoding: String.Encoding.utf8)
            try copy(
                base: tempUrl,
                to: "/etc/systemd/system/\(serviceFile)",
                fromFiles: [serviceFile]
            )
            try run(execute: "systemctl daemon-reload; systemctl restart \(serviceFile)")
        }
    }

    func execString(command: String) -> String {
        var execTask: String

        if let user = self.execUser {
            execTask = "su \(user) -c \"\(command)\""
        } else {
            execTask = command
        }
        if let escalate = self.escalate {
            if let password = self.escalatePassword {
                // Password is add to the environment.
                self.environment["ESCALATEPASSWORD"] = password
                execTask = "echo -e \"${ESCALATEPASSWORD}\" | \(escalate) --stdin \(execTask)"
            } else {
                execTask = "\(escalate) \(execTask)"
            }
        }
        return execTask
    }
}


class ExecuteLocal: Execution {
    override func probe() throws {
        for (key, value) in PlatformArgs() {
            let targetKey = key.replacingOccurrences(of: "BUILD", with: "TARGET")
            self.environment[targetKey] = value
        }
        self.environment["PATH"] = ProcessInfo.processInfo.environment["PATH"]
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
            throw RouterError.FailedExecution(message: "FAILED: \(command)")
        }
    }
}


class ExecuteEcho: ExecuteLocal {
    override func run(execute: String) throws {
        print("Target: \(String(describing: self.target))")
        let execTask = execString(command: execute)
        print(execTask)
    }

    override func copy(base: URL, to: String, fromFiles: [String]) throws {
        print("Target: \(String(describing: self.target))")
        for file in fromFiles {
            let fromUrl = base.appendingPathComponent(file)
            print(fromUrl.path, to)
        }
    }
}


class ExecuteSSH: Execution {
    override func connect() throws -> SSH {
        let cssh = try SSH(host: self.server)
        if let privatekey = self.cliParams.connectionKey {
            try cssh.authenticate(username: self.user, privateKey: privatekey)
        } else {
            try cssh.authenticateByAgent(username: self.user)
        }
        cssh.ptyType = .vanilla
        return cssh
    }

    private func outputStrip(output: String) -> String {
        return output.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    override func probe() throws {
        //    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
        //    TARGETOS - OS component of TARGETPLATFORM
        //    TARGETARCH - architecture component of TARGETPLATFORM
        let unameLookup = ["x86_64": "amd64", "armv7l": "arm/v7", "armv8l": "arm/v8"]
        let (status, output) = try self.ssh!.capture("uname -ms")
        if status == 0 {
            let lowerOutput = outputStrip(output: output).components(separatedBy: " ")
            let os = lowerOutput.first!
            let arch = unameLookup[lowerOutput.last!] ?? "unknown"
            self.environment["TARGETOS"] = os
            self.environment["TARGETARCH"] = arch
            self.environment["TARGETPLATFORM"] = "\(os)/\(arch)"
        }

        let (statusPath, outputPath) = try self.ssh!.capture("echo ${PATH}")
        if statusPath == 0 {
            self.environment["PATH"] = outputStrip(output: outputPath)
        }
    }

    override func copy(base: URL, to: String, fromFiles: [String]) throws {
        let toUrl = URL(fileURLWithPath: to)
        for file in fromFiles {
            let fromUrl = base.appendingPathComponent(file)
            let toFile = toUrl.appendingPathComponent(fromUrl.lastPathComponent)
            do {
                try self.ssh!.sendFile(localURL: fromUrl, remotePath: toUrl.path)
            } catch {
                try self.ssh!.sendFile(localURL: fromUrl, remotePath: toFile.path)
            }
        }
    }

    override func run(execute: String) throws {
        try self.ssh!.execute(execString(command: execute))
    }
}
