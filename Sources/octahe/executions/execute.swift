//
//  execute.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

class Execution {
    let cliParams: OctaheCLI.Options
    let processParams: ConfigParse
    var steps: Int = 0
    var shell: String = "/bin/sh -c"
    var escallation: String?
    var environment: [String: String] = [:]
    var execUser: String?
    var execGroup: String?
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

    func runReturn(execute: String) throws -> String {
        preconditionFailure("This method is not supported")
    }

    func mkdir(workdirURL: URL) throws {
        preconditionFailure("This method is not supported")
    }

    func chown(perms: String?, path: String) throws {
        preconditionFailure("This method is not supported")
    }

    func copy(base: URL, copyTo: String, fromFiles: [String], chown: String? = nil) throws {
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

    func writeTemp(content: String) throws -> URL {
        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        let marker = String(describing: self.target)
        let tempServiceFile = tempUrl.appendingPathComponent(String(describing: "\(marker)-\(content.sha1)").sha1)
        if !FileManager.default.fileExists(atPath: tempServiceFile.path) {
            try content.write(to: tempServiceFile, atomically: true, encoding: String.Encoding.utf8)
        }
        return tempServiceFile
    }

    func serviceTemplate(entrypoint: String) throws {
        // Generate a local template, and transfer it to the remote host
        let serviceFile = "octahe-" + entrypoint.sha1 + ".service"
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
        let tempServiceFile = try self.writeTemp(content: serviceRendered)
        defer {
            try? FileManager.default.removeItem(at: tempServiceFile)
        }
        try self.copy(
            base: tempServiceFile.deletingLastPathComponent(),
            copyTo: "/etc/systemd/system/\(serviceFile)",
            fromFiles: [tempServiceFile.lastPathComponent]
        )
        try self.run(execute: "systemctl daemon-reload")
        try self.run(execute: "systemctl restart \(serviceFile)")
    }

    func execString(command: String) -> String {
        var execTask: String
        let quotedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        if let user = self.execUser {
            execTask = "su \(user) -c \"\(quotedCommand)\""
        } else {
            execTask = quotedCommand
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