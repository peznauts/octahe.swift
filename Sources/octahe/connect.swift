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
    var steps: Int = 0
    var statusLine: String = ""
    var shell: String?

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

    func run(execute: String) throws {
        var runCommand: String
        if self.shell != nil {
            // Setup the execution shell
            runCommand = "\(self.shell!) \"\(execute)\""
        } else {
            // set dummp execution string
            runCommand = execute
        }
        // run execution command
    }

    func copy(to: String, fromFiles: [String]) throws {
        for file in fromFiles {
            // file location transfer "to" destination
        }
    }

    func serviceTemplate(command: String?, entrypoint: String?, entrypointOptions: typeEntrypointOptions) throws {
        // Generate a local template, and transfer it to the remote host
        print("Creating serive templates")
        let hashedFile = entrypoint ?? command
        if hashedFile != nil {
            let serviceFile = "octahe-" + hashedFile!.md5 + ".service"
            try copy(to: "/etc/systemd/system/" + serviceFile, fromFiles: ["/tmp/" + serviceFile])
        }

    }
}


class ExecuteSSH: Execution {
    var server: String = "localhost"
    var port: String = "22"
    var user: String = NSUserName()

    override func connect(target: String) throws {
        // Initiate a connection via ssh.
    }

    override func run(execute: String) throws {
        // delete me later, this is just used to test failure conditions.
        try super.run(execute: execute)
        if self.server == "test1" {
            throw RouterError.NotImplemented(message: "fail")
        }
    }

    override func copy(to: String, fromFiles: [String]) throws {
        // delete me later, this is just used to test failure conditions.
        try super.copy(to: to, fromFiles: fromFiles)
        if self.server == "test2" {
            throw RouterError.NotImplemented(message: "fail")
        }
    }
}
