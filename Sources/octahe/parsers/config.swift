//
//  config.swift
//
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation

func subArgComponentParse(text: String) -> [String] {
    let regex = "(\\S+\'.*?\'|\\S+\".*?\"|\\S+)"
    do {
        let regex = try NSRegularExpression(pattern: regex)
        let results = regex.matches(
            in: text,
            range: NSRange(
                text.startIndex...,
                in: text
            )
        )
        return results.map {
            String(text[Range($0.range, in: text)!]).stripQuotes
        }
    } catch let error {
        logger.warning("\(error.localizedDescription)")
        return []
    }
}

// swiftlint:disable type_body_length
class ConfigParse {
    let configFiles: [(key: String, value: String)]
    var octaheArgs: [String: String]
    var octaheFrom: [String] = []
    var octaheFromHash: [String: TypeFrom] = [:]
    var octaheTargets: [String] = []
    var octaheTargetHash: [String: TypeTarget] = [:]
    var octaheTargetsCount: Int = 0
    var octaheDeploy: [(key: String, value: TypeDeploy)] = []
    var octaheSshConfigFile: URL?
    let configDirURL: URL
    let parsedOptions: OctaheCLI.Options

    func parseTarget(stringTarget: String) throws -> (TypeTarget, [String]) {
        // Target parse string argyments and return a tuple.
        let arrayTarget = subArgComponentParse(text: stringTarget)
        let parsedTarget = try OptionsTarget.parse(arrayTarget)
        let targetNode: TypeTarget
        let targetComponents = parsedTarget.target.components(separatedBy: "@")
        let serverPort = targetComponents.last!.components(separatedBy: ":")

        targetNode = TypeTarget(domain: serverPort.first!, name: parsedTarget.name ?? parsedTarget.target)

        if targetComponents.count > 1 {
            targetNode.user = targetComponents.first ?? nil
        }

        if serverPort.count > 1 {
            if serverPort.last!.isInt {
                targetNode.port = try serverPort.last!.toInt()
            }
        }

        targetNode.escalate = parsedTarget.escalate ?? self.parsedOptions.escalate
        targetNode.viaName = parsedTarget.via.last ?? nil
        if let keyFile = parsedTarget.connectionKey {
            targetNode.key = URL(fileURLWithPath: keyFile)
        }

        return (
            targetNode,
            parsedTarget.via
        )
    }

    func parseAddCopy(stringAddCopy: String) throws -> TypeDeploy {
        // Target parse string argyments and return a tuple.
        let arrayCopyAdd = subArgComponentParse(text: stringAddCopy)
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

    func parseFrom(stringFrom: String) throws -> TypeFrom {
        // Target parse string argyments and return a tuple.
        let arrayFrom = subArgComponentParse(text: stringFrom)
        let parsedFrom = try OptionsFrom.parse(arrayFrom)
        let name = parsedFrom.name ?? parsedFrom.image
        let fromData = (
            platform: parsedFrom.platform,
            image: parsedFrom.image,
            name: name
        )
        return fromData
    }

    func parseExpose(stringExpose: String) throws -> TypeExposes {
        func protoSplit(protoPort: String) throws -> (Int32, String) {
            let protoPortData = protoPort.components(separatedBy: "/")
            let portInt = try protoPortData.first!.toInt()
            let proto: String
            if protoPortData.first! == protoPortData.last! {
                proto = "tcp"
            } else {
                proto = protoPortData.last!.lowercased()
            }
            return (portInt, proto)
        }

        // Target parse string argyments and return a tuple.
        let arrayExpose = subArgComponentParse(text: stringExpose)
        let parsedExpose = try OptionsExpose.parse(arrayExpose)
        var portInt: Int32
        var natInt: Int32?
        var proto: String? = "tcp"

        if !parsedExpose.port.isInt {
            (portInt, proto) = try protoSplit(protoPort: parsedExpose.port)
        } else {
            portInt = try parsedExpose.port.toInt()
        }

        if let natPort = parsedExpose.nat {
            (natInt, proto) = try protoSplit(protoPort: natPort)
        }

        return (
            port: portInt,
            nat: natInt,
            proto: proto
        )
    }

    func viaLoad(viaHosts: [String]) throws {
        let viaCount = viaHosts.count
        let viaHostsReversed = Array(viaHosts.reversed())
        if viaCount > 0 {
            for (index, element) in viaHostsReversed.enumerated() {
                if !self.octaheTargetHash.keys.contains(element) {
                    let targetNode: TypeTarget
                    let targetComponents = element.components(separatedBy: "@")
                    let serverPort = targetComponents.last!.components(separatedBy: ":")

                    targetNode = TypeTarget(domain: serverPort.first!, name: element)
                    if targetComponents.count > 1 {
                        targetNode.user = targetComponents.first ?? nil
                    }
                    if serverPort.count > 1 {
                        if serverPort.last!.isInt {
                            targetNode.port = try serverPort.last!.toInt()
                        }
                    }

                    targetNode.viaName = viaHostsReversed.getNextElement(index: index) ?? nil
                    self.octaheTargetHash[element] = targetNode
                }
            }
        }
    }

    func entrypointParsing() throws {
        let entrypointConfigs = ["HEALTHCHECK", "STOPSIGNAL", "CMD", "ENTRYPOINT"]
        let entrypointOptions = self.configFiles.filter {key, _ in
            return entrypointConfigs.contains(key)
        }
        for entrypointOption in entrypointConfigs {
            if let item = entrypointOptions.filter({$0.key == entrypointOption}).last {
                if entrypointOption == "HEALTHCHECK" {
                    let healthcheckComponents = item.value.components(separatedBy: "CMD")
                    let healthcheckArgs = subArgComponentParse(text: healthcheckComponents.first!.strip)
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

    // swiftlint:disable function_body_length
    func deploymentCases(_ deployOption: (key: String, value: String)) throws -> TypeDeployCase {
        switch deployOption.key {
        case "COPY", "ADD":
            let addCopy = try parseAddCopy(stringAddCopy: deployOption.value)
            return (
                key: deployOption.key,
                value: addCopy
            )
        case "ARG", "ENV", "LABEL":
            let argDictionary = buildDictionary(
                filteredContent: [(key: deployOption.key, value: deployOption.value)]
            )
            return (
                key: deployOption.key,
                value: TypeDeploy(
                    original: deployOption.value,
                    env: argDictionary
                )
            )
        case "USER":
            let trimmedUser = deployOption.value.strip.components(separatedBy: ":")
            return (
                key: deployOption.key,
                value: TypeDeploy(
                    original: deployOption.value,
                    user: trimmedUser.first,
                    group: trimmedUser.last
                )
            )
        case "EXPOSE":
            return (
                key: deployOption.key,
                value: TypeDeploy(
                    original: deployOption.value,
                    exposeData: try parseExpose(stringExpose: deployOption.value)
                )
            )
        case "WORKDIR":
            return (
                key: deployOption.key,
                value: TypeDeploy(
                    original: deployOption.value,
                    workdir: deployOption.value
                )
            )
        case "RUN":
            return (
                key: deployOption.key,
                value: TypeDeploy(
                    execute: String(describing: deployOption.value),
                    original: deployOption.value
                )
            )
        default:
            return (
                key: deployOption.key,
                value: TypeDeploy(
                    execute: deployOption.value,
                    original: deployOption.value
                )
            )
        }
    }

    func deploymentParsing(_ deployOptions: [(key: String, value: String)]) throws {
        for deployOption in deployOptions {
            self.octaheDeploy.append(try self.deploymentCases(deployOption))
        }
    }

    func targetParsing() throws {
        var targets: [String] = []
        if self.parsedOptions.targets.count >= 1 {
            for target in self.parsedOptions.targets {
                let (target, viaHosts) = try self.parseTarget(stringTarget: target)
                try self.viaLoad(viaHosts: viaHosts)
                self.octaheTargetHash[target.name] = target
                targets.append(target.name)
            }
        } else {
            let filteredTargets = self.configFiles.filter {$0.key == "TO"}
            for target in filteredTargets {
                let (target, viaHosts) = try self.parseTarget(stringTarget: target.value)
                try self.viaLoad(viaHosts: viaHosts)
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
        self.configFiles = try FileParser().buildRawConfigs(files: self.parsedOptions.configurationFiles)

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
            return ["RUN", "COPY", "ADD", "SHELL", "ARG", "ENV", "USER", "INTERFACE", "EXPOSE",
                    "WORKDIR", "LABEL"].contains(key)
        }
        try self.deploymentParsing(deployOptions)
        try self.entrypointParsing()
        // filter all TARGETS.
        try self.targetParsing()
        // Add any extra args into the deployment head
        for extraArgs in self.parsedOptions.args {
            let argDictionary = buildDictionary(
                filteredContent: [(key: "ARG", value: extraArgs)]
            )
            self.octaheDeploy.insert(
                (
                    key: "ARG",
                    value: TypeDeploy(
                        original: extraArgs,
                        env: argDictionary
                    )
                ),
                at: 0
            )
        }
    }
}
