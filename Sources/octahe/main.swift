//
//  main.swift
//  
//
//  Created by Kevin Carter on 6/4/20.
//

// test args made using docs https://github.com/apple/swift-argument-parser/blob/master/Documentation/02%20Arguments%2C%20Options%2C%20and%20Flags.md

import Foundation

import ArgumentParser

struct Octahe: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Octahe, a utility for deploying OCI compatible applications.",
        subcommands: [Deploy.self],
        defaultSubcommand: Deploy.self
    )
    struct Options: ParsableArguments {
        @Flag(name: [.customLong("booldata"), .customShort("q")], help: "Boolean Option.")
        var boolOption: Bool

        @Option(name: .shortAndLong, help: "Some integer to print.")
        var integerOption: Int?

        @Argument(help: "Some positional argument.")
        var positionalArgs: String

        mutating func run() throws {
            print(integerOption as Any, boolOption, positionalArgs)
        }
    }
}

extension Octahe {
    struct Deploy: ParsableCommand {
        static var configuration
            = CommandConfiguration(abstract: "Run a deployment for a given OCI compatible application.")

        @OptionGroup()
        var options: Octahe.Options
        
        mutating func run() {
            print("Hello, World")
        }
    }
}

Octahe.main()
