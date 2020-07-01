//
//  File.swift
//  
//
//  Created by Kevin Carter on 6/25/20.
//

import Foundation

class ExecuteEcho: Execution {
    override init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        super.init(cliParameters: cliParameters, processParams: processParams)
    }

    private func notice() {
        print("Target: \(String(describing: self.target))")
    }

    override func probe() throws {
        notice()
        print("Environment options are generated here.")
    }

    override func run(execute: String) throws {
        notice()
        let execTask = self.execPosixString(command: execute)
        print(execTask)
    }

    override func mkdir(workdirURL: URL) throws {
        print(workdirURL)
    }

    override func copy(base: URL, copyTo: String, fromFiles: [String], chown: String? = nil) throws {
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
