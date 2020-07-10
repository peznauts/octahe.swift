//
//  cli.swift
//
//
//  Created by Kevin Carter on 6/18/20.
//

import Foundation

import ArgumentParser

protocol OctaheArguments: ParsableArguments {
    // Basic sub-structure
}

struct OptionsTarget: OctaheArguments {
    // Add option parsing for target configs found within config.
    @Option(
        name: .long,
        help: """
              Proxy target.
              """
    )
    var via: [String]

    @Option(
        name: .long,
        help: """
              Escalation binary.
              """
    )
    var escalate: String?

    @Option(
        name: .long,
        help: """
              Friendly node name.
              """
    )
    var name: String?

    @Option(
        name: [.customLong("connection-key"), .customShort("k")],
        help: """
              Key used to initiate a connection.
              """
    )
    var connectionKey: String?

    @Argument(
        help: """
              Target host.
              """
    )
    var target: String
}

struct OptionsAddCopy: OctaheArguments {
    // Add option parsing for target configs found within config.
    @Option(
        name: .long,
        help: """
              Set the owner of a file or directory.
              """
    )
    var chown: String?

    @Option(
        name: .long,
        help: """
              This argument is unused and kept only for OCI file compatibility.
              """
    )
    var from: String?

    @Argument(
        help: """
              File transfers, the last string in the argument is used as
              the destination.
              """
    )
    var transfer: [String]
}

struct OptionsFrom: OctaheArguments {
    // Add option parsing for target configs found within config.
    @Option(
        name: .long,
        help: """
              Used to specify the platform of a base image.
              """
    )
    var platform: String?

    @Argument(
        help: """
              Image information.
              """
    )
    var image: String

    // swiftlint:disable identifier_name
    @Argument(
        help: """
              AS information.
              """
    )
    var AS: String?

    @Argument(
        help: """
              Name information.
              """
    )
    var name: String?
}

struct OptionsExpose: OctaheArguments {
    // Add option parsing for target configs found within config.
    @Argument(
        help: """
              Used to expose a given port
              """
    )
    var port: String

    @Argument(
        help: "Nat port."
    )
    var nat: String?
}

struct OptionsHealthcheck: OctaheArguments {
    @Option(
        name: .long,
        default: "30s",
        help: """
              Specify a healthcheck interval.
              """
    )
    var interval: String

    @Option(
        name: .long,
        default: "30s",
        help: """
              Specify how long a healthcheck can run before it gives up.
              """
    )
    var timeout: String

    @Option(
        name: .long,
        default: "30s",
        help: """
              Specify a period of time to wait before a healthcheck is
              started.
              """
    )
    var startPeriod: String

    @Option(
        name: .long,
        default: 3,
        help: """
              Specify the number of retries used before a service is marked
              unhealth.
              """
    )
    var retries: Int
}

struct OctaheCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Octahe, a utility for deploying OCI compatible applications.",
        subcommands: [
            Deploy.self,
            UnDeploy.self,
            Target.self,
            AddCopy.self,
            From.self,
            Expose.self,
            Healthcheck.self
        ],
        defaultSubcommand: Deploy.self
    )
    struct Options: ParsableArguments {
        // Global options used in with all subcommands.
        @Option(
            name: .shortAndLong,
            help: """
                  Extra arguments that will be applied to the system at runtime.
                  This option can be used multiple times and requires a single
                  string per entry, using the following format:
                  <name>[=<default value>]
                  """
        )
        var args: [String]

        @Option(
            name: [.customLong("connection-key"), .customShort("k")],
            help: """
                  Key used to initiate a connection.
                  """
        )
        var connectionKey: String?

        @Option(
            name: .shortAndLong,
            default: 1,
            help: """
                  Limit the total number of concurrent connections per group.
                  """
        )
        var connectionQuota: Int

        @Flag(
            help: """
                  Dry run. This option will perform all nessisary introspection
                  and compile an application deployment plan; it will NOT run
                  the compiled application deployment plan.
                  """
        )
        var dryRun: Bool

        @Flag(
            help: """
                  Enable debug mode, when this is enabled log messages will be
                  printed to screen instead of the normal, simple, system output.
                  """
        )
        var debug: Bool

        @Option(
            name: .shortAndLong,
            help: """
                  Escalation binary and any flags desired.
                  Example: "/usr/bin/sudo --preserve-env"
                  """
        )
        var escalate: String?

        @Option(
            name: [.customLong("escalation-pw"), .customShort("p")],
            help: """
                  Passowrd used for privledge escallation.
                  """
        )
        var escalatePassword: String?

//        @Option(
//            name: .shortAndLong,
//            help: """
//                  Log file. When set the application will save log messages to
//                  a file using the provided path.
//                  """
//        )
//        var logFile: String?

        @Option(
            name: .shortAndLong,
            help: """
                  Override or set targets. Any specified on the CLI will be"
                  the only targets used within a given execution.
                  """
        )
        var targets: [String]

        @Argument(
            help: """
                  Configuration file(s) used to build an application deployment
                  plan.
                  """
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

extension OctaheCLI {
    struct Deploy: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Run a deployment for a given OCI compatible application."
        )

        @OptionGroup()
        var options: OctaheCLI.Options

        func run() throws {
            print("Beginning deployment execution")
            try Router(parsedOptions: options, function: ExecutionStates.deploy).main()
        }
    }

    struct UnDeploy: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "undeploy",
            abstract: "Disable a deployment for a given OCI compatible application."
        )

        @OptionGroup()
        var options: OctaheCLI.Options

        func run() throws {
            try Router(parsedOptions: options, function: ExecutionStates.undeploy).main()
        }
    }

    struct Target: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "options_target",
            abstract: "Show options when handling the TO directive.",
            shouldDisplay: false
        )

        @OptionGroup()
        var options: OptionsTarget
    }

    struct AddCopy: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "options_add_copy",
            abstract: "Show options used when handling the COPY/ADD directives.",
            shouldDisplay: false
        )

        @OptionGroup()
        var options: OptionsAddCopy
    }

    struct From: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "options_from",
            abstract: "Show options used when handling the FROM directive.",
            shouldDisplay: false
        )

        @OptionGroup()
        var options: OptionsFrom
    }

    struct Expose: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "options_expose",
            abstract: "Show options used when handling the EXPOSE directive.",
            shouldDisplay: false
        )

        @OptionGroup()
        var options: OptionsExpose
    }

    struct Healthcheck: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "options_healthcheck",
            abstract: "Show options used when handling the HEALTHCHECK directive.",
            shouldDisplay: false
        )

        @OptionGroup()
        var options: OptionsHealthcheck
    }
}
