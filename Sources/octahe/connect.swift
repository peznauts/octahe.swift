//
//  connect.swift
//  
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation


class Execution {
    let cliParams: Octahe.Options
    let processParams: ConfigParse

    init(cliParameters: Octahe.Options, processParams: ConfigParse) {
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

    private func run(execute: String) {
        print("RUN:", execute)
    }

    private func copy(to: String, from: [String]) {
        for file in from {
            print("ADD or COPY:", file, to)
        }
    }

    func deploy(deployItem: typeDeploy) throws {
        if deployItem.execute != nil {
            run(execute: deployItem.execute!)
        } else if deployItem.destination != nil && deployItem.location != nil {
            copy(to: deployItem.destination!, from: deployItem.location!)
        }
    }

    func serviceTemplate(command: String?, entrypoint: String?, entrypointOptions: typeEntrypointOptions) {
        // Generate a local template, and transfer it to the remote host
        print("Creating serive templates")
        let hashedFile = entrypoint ?? command
        if hashedFile != nil {
            let serviceFile = "octahe-" + hashedFile!.md5 + ".service"
            copy(to: "/etc/systemd/system/" + serviceFile, from: ["/tmp/" + serviceFile])
        }

    }
}


class ExecuteSSH: Execution {
    var server: String = "localhost"
    var port: String = "22"
    var user: String = NSUserName()

    override func connect(target: String) throws {
        let targetData = self.processParams.octaheTargetHash[target]!
        if targetData.via != target {
            
        }
        let targetComponents = targetData.to.components(separatedBy: "@")
        if targetComponents.count > 1 {
            self.user = targetComponents.first!
        }

        let serverPort = targetComponents.last!.components(separatedBy: ":")
        if serverPort.count > 1 {
            self.server = serverPort.first!
            self.port = serverPort.last!
        } else {
            self.server = serverPort.first!
        }

        if !self.port.isInt {
            throw RouterError.FailedConnection(
                message: "Connection never attempted because the port is not an integer.",
                targetData: targetData
            )
        }
        print("Connecting to host. user:", user, "server:", server, "port:", port)
    }
}
