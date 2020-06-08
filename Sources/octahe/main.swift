//
//  main.swift
//  
//
//  Created by Kevin Carter on 6/4/20.
//

// test args made using docs:
// https://github.com/apple/swift-argument-parser/blob/master/Documentation/

import Foundation

import ArgumentParser

struct Octahe: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Octahe, a utility for deploying OCI compatible applications.",
        subcommands: [Deploy.self, UnDeploy.self],
        defaultSubcommand: Deploy.self
    )
    struct Options: ParsableArguments {
        // Global options used in with all subcommands.
        @Option(
            name: [.customLong("connection-key"), .customShort("k")],
            help: "Key used to initiate a connection."
        )
        var connectionKey: String?

        @Option(
            name: .shortAndLong,
            help: "Limit the total number of concurrent connections per group."
        )
        var connectionQuota: Int?
        
        @Flag(
            help: """
                  Dry run. This option will perform all nessisary introspection, compile an application deployment
                  plan, and validate connectivity to targets; it will NOT run the compiled application deployment
                  plan.
                  """
        )
        var dryRun: Bool
        
        @Option(
            name: .shortAndLong,
            help: "Escalation binary."
        )
        var escalate: String?
        
        @Option(
            name: [.customLong("escalation-pw"), .customShort("p")],
            help: "Passowrd used for privledge escallation."
        )
        var escalatePassword: String?

        @Option(
            name: .shortAndLong,
            help: """
                  Override or set targets. Any specified on the CLI will be"
                  the only targets used within a given execution.
                  """
        )
        var targets: [String]
        
        @Argument(
            help: "Configuration file(s) used to build an application deployment plan."
        )
        var configurationFiles: [String]
        
        mutating func validate() throws {
            guard !configurationFiles.isEmpty else {
                throw ValidationError(
                    "Please provide at least one OCI compatible configuration file to parse."
                )
            }
        }
    }
}

extension Octahe {
    struct Deploy: ParsableCommand {
        static var configuration = CommandConfiguration(
                abstract: "Run a deployment for a given OCI compatible application."
        )

        @OptionGroup()
        var options: Octahe.Options
        
        func run() throws {
            print("Beginning deployment execution")
            try CoreRouter(parsedOptions: options, function: "deploy")
        }
    }
    
    struct UnDeploy: ParsableCommand {
        static var configuration = CommandConfiguration(
                abstract: "Disable a deployment for a given OCI compatible application."
        )

        @OptionGroup()
        var options: Octahe.Options
        
        func run() throws {
            print("Beginning undeployment execution")
            try CoreRouter(parsedOptions: options, function: "undeploy")
        }
    }
}

Octahe.main()
