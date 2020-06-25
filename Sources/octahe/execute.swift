//
//  execute.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

import Shout
import SwiftSerial

class Execution {
    let cliParams: OctaheCLI.Options
    let processParams: ConfigParse
    var steps: Int = 0
    var shell: String = "/bin/sh -c"
    var escallation: String?
    var environment: [String: String] = [:]
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
    var documentation: [[String: String]] = [["item": "https://github.com/peznauts/octahe.swift"]]
    var ssh: SSH?
    var serialPort: SerialPort?

    init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        self.cliParams = cliParameters
        self.processParams = processParams
        self.workdirURL = URL(fileURLWithPath: workdir)
    }

    func connect() throws {
        preconditionFailure("This method is not supported")
    }

    func probe() throws {
        // Sourced from remote target at runtime:
        //    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
        //    TARGETOS - OS component of TARGETPLATFORM
        //    TARGETARCH - architecture component of TARGETPLATFORM
        //    TARGETVARIANT - variant component of TARGETPLATFORM
        preconditionFailure("This method is not supported")
    }

    func close() {
        preconditionFailure("This method is not supported")
    }

    func run(execute: String) throws {
        preconditionFailure("This method is not supported")
    }

    func copy(base: URL, copyTo: String, fromFiles: [String]) throws {
        preconditionFailure("This method is not supported")
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
        try run(execute: "\(commandDelete) &> /dev/null || true")
        try run(execute: "\(commandCreate)")
    }

    private func optionFormat(options: [String: String]) -> [[String: String]] {
        var items: [[String: String]]  = []
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
            try serviceRendered.write(to: tempService, atomically: true, encoding: String.Encoding.utf8)
            try self.copy(
                base: tempUrl,
                copyTo: "/etc/systemd/system/\(serviceFile)",
                fromFiles: [serviceFile]
            )
            try self.run(execute: "systemctl daemon-reload")
            try self.run(execute: "systemctl restart \(serviceFile)")
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
                execTask = "echo -e \"${ESCALATEPASSWORD}\" | \(escalate) --stdin \(self.shell) \"\(execTask)\""
            } else {
                execTask = "\(escalate) \(self.shell) \"\(execTask)\""
            }
        }
        return execTask
    }
}

class ExecuteLocal: Execution {
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

class ExecuteEcho: Execution {
    private func notice() {
        print("Target: \(String(describing: self.target ?? self.server))")
    }

    override func probe() throws {
        notice()
        print("Environment options are generated here.")
    }

    override func run(execute: String) throws {
        notice()
        let execTask = execString(command: execute)
        print(execTask)
    }

    override func copy(base: URL, copyTo: String, fromFiles: [String]) throws {
        notice()
        for file in fromFiles {
            let fromUrl = base.appendingPathComponent(file)
            print(fromUrl.path, copyTo)
        }
    }

    override func serviceTemplate(entrypoint: String) throws {
        notice()
        print(entrypoint)
        try super.serviceTemplate(entrypoint: entrypoint)
    }
}

class ExecuteSSH: Execution {
    override func connect() throws {
        let cssh = try SSH(host: self.server)
        if let privatekey = self.cliParams.connectionKey {
            try cssh.authenticate(username: self.user, privateKey: privatekey)
        } else {
            try cssh.authenticateByAgent(username: self.user)
        }
        self.ssh = cssh
    }

    private func outputStrip(output: String) -> String {
        return output.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    override func probe() throws {
        //    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
        //    TARGETOS - OS component of TARGETPLATFORM
        //    TARGETARCH - architecture component of TARGETPLATFORM
        let unameLookup = ["x86_64": "amd64", "armv7l": "arm/v7", "armv8l": "arm/v8"]
        let (status, output) = try self.ssh!.capture("uname -ms; systemctl --version; echo ${PATH}")
        if status == 0 {
            let lowerOutput = outputStrip(output: output).components(separatedBy: "\n")
            let targetVars = lowerOutput.first!.components(separatedBy: " ")
            let kernel = self.outputStrip(output: targetVars.first!)
            let archRaw = self.outputStrip(output: targetVars.last!)
            let arch = unameLookup[archRaw] ?? "unknown"
            let systemd = lowerOutput[1].components(separatedBy: " ")
            self.environment["TARGETOS"] = kernel
            self.environment["TARGETARCH"] = arch
            self.environment["TARGETPLATFORM"] = "\(kernel)/\(arch)"
            self.environment["SYSTEMD_VERSION"] = self.outputStrip(output: systemd.last!)
            self.environment["PATH"] = outputStrip(output: lowerOutput.last!)
        } else {
            throw RouterError.failedExecution(message: output)
        }
    }

    private func runCopy(fromUrl: URL, toUrl: URL, toFile: URL) throws {
        do {
            try self.ssh!.sendFile(localURL: fromUrl, remotePath: toUrl.path)
        } catch {
            try self.ssh!.sendFile(localURL: fromUrl, remotePath: toFile.path)
        }
    }

    override func copy(base: URL, copyTo: String, fromFiles: [String]) throws {
        let toUrl: URL = URL(fileURLWithPath: copyTo)
        for file in fromFiles {
            let fromUrl = base.appendingPathComponent(file)
            let toFile = toUrl.appendingPathComponent(fromUrl.lastPathComponent)
            if self.escalate != nil {
                let tempUrl = URL(fileURLWithPath: "/tmp")
                let fileUrl = URL(fileURLWithPath: file)
                let tempFileUrl = tempUrl.appendingPathComponent(fileUrl.lastPathComponent)
                try runCopy(fromUrl: fromUrl, toUrl: tempFileUrl, toFile: tempFileUrl)
                try run(execute: "mv \(tempFileUrl.path) \(toUrl.path)")
            } else {
                try runCopy(fromUrl: fromUrl, toUrl: toUrl, toFile: toFile)
            }
        }
    }

    override func run(execute: String) throws {
        let (status, output) = try self.ssh!.capture(execString(command: execute))
        if status != 0 {
            throw RouterError.failedExecution(message: "FAILED execution: \(output)")
        }

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

class ExecuteSerial: Execution {
    override func connect() throws {
        self.serialPort = SerialPort(path: self.target!)
        self.serialPort!.setSettings(
            receiveRate: .baud9600,
            transmitRate: .baud9600,
            minimumBytesToRead: 1
        )
        try self.serialPort!.openPort()
    }

    override func close() {
        self.serialPort!.closePort()
    }

    override func probe() throws {
        logger.info("Environment options are irrelevant with serial ports.")
    }

    override func copy(base: URL, copyTo: String, fromFiles: [String]) throws {
        guard fromFiles.count > 1 else {
            throw RouterError.notImplemented(message: "Only one file can be written to a serial port")
        }
        let fromUrl = base.appendingPathComponent(fromFiles.first!)
        let fileData = try Data(contentsOf: fromUrl)
        _ = try self.serialPort?.writeData(fileData)
    }

    override func run(execute: String) throws {
        _ = try self.serialPort?.writeString(execute)
    }
    override func serviceTemplate(entrypoint: String) throws {
        preconditionFailure("This method is not supported")
    }
}
