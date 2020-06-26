//
//  config.swift
//  
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation

struct ConfigParse {
    let configFiles: [(key: String, value: String)]
    var octaheArgs: [String: String]
    var octaheFrom: [String] = []
    var octaheFromHash: [String: TypeFrom] = [:]
    var octaheTargets: [String] = []
    var octaheTargetHash: [String: TypeTarget] = [:]
    var octaheTargetsCount: Int = 0
    var octaheDeploy: [(key: String, value: TypeDeploy)] = []
    let configDirURL: URL
    let parsedOptions: OctaheCLI.Options

    func parseTarget(stringTarget: String) throws -> (TypeTarget, [String]) {
        // Target parse string argyments and return a tuple.
        let arrayTarget = stringTarget.components(separatedBy: " ")
        let parsedTarget = try OptionsTarget.parse(arrayTarget)
        let viaHost = parsedTarget.via.last ?? "localhost"
        return (
            (
                to: parsedTarget.target,
                via: viaHost,
                escalate: parsedTarget.escalate ?? self.parsedOptions.escalate,
                name: parsedTarget.name ?? parsedTarget.target
            ),
            parsedTarget.via
        )
    }

    mutating func parseAddCopy(stringAddCopy: String) throws -> TypeDeploy {
        // Target parse string argyments and return a tuple.
        let arrayCopyAdd = stringAddCopy.components(separatedBy: " ")
        var parsedCopyAdd = try OptionsAddCopy.parse(arrayCopyAdd)
        let destination = parsedCopyAdd.transfer.last
        parsedCopyAdd.transfer.removeLast()
        let location = parsedCopyAdd.transfer
        return TypeDeploy(
            chown: parsedCopyAdd.chown,
            location: location,
            destination: destination,
            from: parsedCopyAdd.from,
            original: stringAddCopy
        )
    }

    mutating func parseFrom(stringFrom: String) throws -> TypeFrom {
        // Target parse string argyments and return a tuple.
        let arrayFrom = stringFrom.components(separatedBy: " ")
        let parsedFrom = try OptionsFrom.parse(arrayFrom)
        let name = parsedFrom.name ?? parsedFrom.image
        let fromData = (
            platform: parsedFrom.platform,
            image: parsedFrom.image,
            name: name
        )
        return fromData
    }

    mutating func parseExpose(stringExpose: String) throws -> TypeExposes {
        func protoSplit(protoPort: String) -> (Int, String) {
            let protoPortData = protoPort.split(separator: "/", maxSplits: 1)
            let portInt = (protoPortData.first! as NSString).integerValue
            let proto: String
            if protoPortData.first! == protoPortData.last! {
                proto = "tcp"
            } else {
                proto = protoPortData.last!.lowercased()
            }
            return (portInt, proto)
        }

        // Target parse string argyments and return a tuple.
        let arrayExpose = stringExpose.components(separatedBy: " ")
        let parsedExpose = try OptionsExpose.parse(arrayExpose)
        var portInt: Int
        var natInt: Int?
        var proto: String? = "tcp"

        if !parsedExpose.port.isInt {
            (portInt, proto) = protoSplit(protoPort: parsedExpose.port)
        } else {
            portInt = (parsedExpose.port as NSString).integerValue
        }

        if let natPort = parsedExpose.nat {
            (natInt, proto) = protoSplit(protoPort: natPort)
        }

        return (
            port: portInt,
            nat: natInt,
            proto: proto
        )
    }

    mutating func viaLoad(viaHosts: [String]) {
        var nextVia: String
        let viaCount = viaHosts.count
        let viaHostsReversed = Array(viaHosts.reversed())
        if viaCount > 0 {
            for (index, element) in viaHostsReversed.enumerated() {
                nextVia = viaHostsReversed.getNextElement(index: index) ?? "localhost"
                self.octaheTargetHash[element] = (
                    to: element,
                    via: nextVia,
                    escalate: nil,
                    name: element
                )
            }
        }
    }

    mutating func entrypointParsing() throws {
        let entrypointConfigs = ["HEALTHCHECK", "STOPSIGNAL", "CMD", "ENTRYPOINT"]
        let entrypointOptions = self.configFiles.filter {key, _ in
            return entrypointConfigs.contains(key)
        }
        for entrypointOption in entrypointConfigs {
            if let item = entrypointOptions.filter({$0.key == entrypointOption}).last {
                if entrypointOption == "HEALTHCHECK" {
                    let healthcheckComponents = item.value.components(separatedBy: "CMD")
                    let healthcheckArgs = healthcheckComponents.first?.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).components(separatedBy: " ")
                    let parsedHealthcheckArgs = try OptionsHealthcheck.parse(healthcheckArgs)
                    print(parsedHealthcheckArgs) // delete me once i figure out what to do with the args.
                    self.octaheDeploy.append(
                        (
                            key: entrypointOption,
                            value: TypeDeploy(
                                execute: healthcheckComponents.last,
                                original: item.value
                            )
                        )
                    )
                } else {
                    self.octaheDeploy.append(
                        (
                            key: entrypointOption,
                            value: TypeDeploy(
                                execute: item.value,
                                original: item.value
                            )
                        )
                    )
                }
            }
        }
    }

    mutating func deploymentCases(_ deployOption: (key: String, value: String)) throws {
        switch deployOption.key {
        case "COPY", "ADD":
            let addCopy = try parseAddCopy(stringAddCopy: deployOption.value)
            self.octaheDeploy.append((key: deployOption.key, value: addCopy))
        case "ARG", "ENV", "LABEL":
            let argDictionary = buildDictionary(
                filteredContent: [(key: deployOption.key, value: deployOption.value)]
            )
            self.octaheDeploy.append(
                (
                    key: deployOption.key,
                    value: TypeDeploy(
                        original: deployOption.value,
                        env: argDictionary
                    )
                )
            )
        case "USER":
            let trimmedUser = deployOption.value.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).components(separatedBy: ":")
            self.octaheDeploy.append(
                (
                    key: deployOption.key,
                    value: TypeDeploy(
                        original: deployOption.value,
                        user: trimmedUser.first,
                        group: trimmedUser.last
                    )
                )
            )
        case "EXPOSE":
            self.octaheDeploy.append(
                (
                    key: deployOption.key,
                    value: TypeDeploy(
                        original: deployOption.value,
                        exposeData: try parseExpose(stringExpose: deployOption.value)
                    )
                )
            )
        case "WORKDIR":
            self.octaheDeploy.append(
                (
                    key: deployOption.key,
                    value: TypeDeploy(
                        original: deployOption.value,
                        workdir: deployOption.value
                    )
                )
            )
        case "RUN":
            self.octaheDeploy.append(
                (
                    key: deployOption.key,
                    value: TypeDeploy(
                        execute: String(describing: deployOption.value),
                        original: deployOption.value
                    )
                )
            )
        default:
            self.octaheDeploy.append(
                (
                    key: deployOption.key,
                    value: TypeDeploy(
                        execute: deployOption.value,
                        original: deployOption.value
                    )
                )
            )
        }
    }

    mutating func deploymentParsing(_ deployOptions: [(key: String, value: String)]) throws {
        for deployOption in deployOptions {
            try self.deploymentCases(deployOption)
        }
    }

    mutating func targetParsing() throws {
        var targets: [String] = []
        if self.parsedOptions.targets.count >= 1 {
            for target in self.parsedOptions.targets {
                let (target, viaHosts) = try parseTarget(stringTarget: target)
                viaLoad(viaHosts: viaHosts)
                self.octaheTargetHash[target.name] = target
                targets.append(target.name)
            }
        } else {
            let filteredTargets = self.configFiles.filter {$0.key == "TO"}
            for target in filteredTargets {
                let (target, viaHosts) = try parseTarget(stringTarget: target.value)
                viaLoad(viaHosts: viaHosts)
                self.octaheTargetHash[target.name] = target
                targets.append(target.name)
            }
        }
        self.octaheTargetsCount = targets.count
        self.octaheTargets = targets
    }

    init(parsedOptions: OctaheCLI.Options, configDirURL: URL) throws {
        self.configDirURL = configDirURL
        self.parsedOptions = parsedOptions
        self.configFiles = try FileParser.buildRawConfigs(files: self.parsedOptions.configurationFiles)

        // Args are merged into a single Dictionary. This will allow us to apply args to wherever they're needed.
        self.octaheArgs = platformArgs()

        // Filter FROM options to send for introspection to return additional config from a container registry.
        let deployFroms = self.configFiles.filter {$0.key == "FROM"}.map {$0.value}
        for deployFrom in deployFroms.reversed() {
            let from = try parseFrom(stringFrom: deployFrom)
            self.octaheFromHash[from.name!] = from
            self.octaheFrom.append(from.name!)
        }

        // Return only a valid config.
        let deployOptions = self.configFiles.filter {key, _ in
            return ["RUN", "COPY", "ADD", "SHELL", "ARG", "ENV", "USER", "EXPOSE", "WORKDIR", "LABEL"].contains(key)
        }
        try self.deploymentParsing(deployOptions)
        try self.entrypointParsing()

        // filter all TARGETS.
        try self.targetParsing()
    }
}
