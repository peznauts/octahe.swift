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

    func execute() {
        preconditionFailure("This method must be overridden")
    }

    func copy() {
        preconditionFailure("This method must be overridden")
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
