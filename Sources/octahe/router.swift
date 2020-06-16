//
//  mixin.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation


struct ConfigParse {
    let configFiles: [(key: String, value: String)]
    var runtimeArgs: Dictionary<String, String>
    var octaheArgs: Dictionary<String, String>
    let octaheLabels: Dictionary<String, String>
    var octaheFrom: [String] = []
    var octaheFromHash: [String: typeFrom] = [:]
    var octaheTargets: [[String]] = []
    var octaheTargetHash: [String: typeTarget] = [:]
    var octaheDeploy: [(key: String, value: typeDeploy)] = []
    var octaheExposes: [(key: String, value: typeExposes)] = []
    let octaheCommand: String?
    let octaheEntrypoints: String?
    let octaheEntrypointOptions: typeEntrypointOptions

    init(parsedOptions: Octahe.Options) throws {
        func parseTarget(stringTarget: String) throws -> (typeTarget, Array<String>) {
            // Target parse string argyments and return a tuple.
            let arrayTarget = stringTarget.components(separatedBy: " ")
            do {
                let parsedTarget = try OptionsTarget.parse(arrayTarget)
                let viaHost = parsedTarget.via.last ?? "localhost"
                return (
                    (
                        to: parsedTarget.target,
                        via: viaHost,
                        escalate: parsedTarget.escalate,
                        name: parsedTarget.name ?? parsedTarget.target
                    ),
                    parsedTarget.via
                )
            } catch {
                throw RouterError.FailedParsing(
                    message: "Parsing TO information has failed",
                    component: stringTarget
                )
            }

        }

        func parseAddCopy(stringAddCopy: String) throws -> typeDeploy {
            // Target parse string argyments and return a tuple.
            let arrayCopyAdd = stringAddCopy.components(separatedBy: " ")
            do {
                var parsedCopyAdd = try OptionsAddCopy.parse(arrayCopyAdd)
                let destination = parsedCopyAdd.transfer.last
                parsedCopyAdd.transfer.removeLast()
                let location = parsedCopyAdd.transfer
                return (
                    execute: nil,
                    chown: parsedCopyAdd.chown,
                    location: location,
                    destination: destination,
                    from: parsedCopyAdd.from
                )
            } catch {
                throw RouterError.FailedParsing(
                    message: "Parsing ADD/COPY information has failed",
                    component: stringAddCopy
                )
            }
        }

        func parseFrom(stringFrom: String) throws -> typeFrom {
            // Target parse string argyments and return a tuple.
            let arrayFrom = stringFrom.components(separatedBy: " ")
            do {
                let parsedFrom = try OptionsFrom.parse(arrayFrom)
                let name = parsedFrom.name ?? parsedFrom.image
                let fromData = (
                    platform: parsedFrom.platform,
                    image: parsedFrom.image,
                    name: name
                )
                return fromData
            } catch {
                throw RouterError.FailedParsing(
                    message: "Parsing FROM information has failed",
                    component: stringFrom
                )
            }
        }

        func parseExpose(stringExpose: String) throws -> typeExposes {
            // Target parse string argyments and return a tuple.
            let arrayExpose = stringExpose.components(separatedBy: " ")
            do {
                let parsedExpose = try OptionsExpose.parse(arrayExpose)
                let natPort = parsedExpose.nat?.split(separator: "/", maxSplits: 1)
                let proto = natPort?[1] ?? "tcp"
                return (
                    port: parsedExpose.port,
                    nat: natPort?.first,
                    proto: proto.lowercased()
                )
            } catch {
                throw RouterError.FailedParsing(
                    message: "Parsing EXPOSE information has failed",
                    component: stringExpose
                )
            }
        }

        func viaLoad(viaHosts: [String]) {
            var nextVia: String
            let viaCount = viaHosts.count
            let viaHostsReversed = Array(viaHosts.reversed())
            if viaCount > 0 {
                for (index, element) in viaHostsReversed.enumerated() {
                    nextVia = viaHostsReversed.getNextElement(index: index) ?? "localhost"
                    print(index, nextVia, element)
                    self.octaheTargetHash[element] = (
                        to: element,
                        via: nextVia,
                        escalate: nil,
                        name: element
                    )
                }
            }
        }

        self.configFiles = try FileParser.buildRawConfigs(files: parsedOptions.configurationFiles)

        // Create a constant containing all lables.
        self.octaheLabels = BuildDictionary(filteredContent: self.configFiles.filter{$0.key == "LABEL"})

        // Args are merged into a single Dictionary. This will allow us to apply args to wherever they're needed.
        self.octaheArgs = PlatformArgs()
        self.runtimeArgs = BuildDictionary(
            filteredContent: self.configFiles.filter{key, value in
                return ["ARG", "ENV"].contains(key)
            }
        )
        self.octaheArgs.merge(self.runtimeArgs) {
            (current, _) in current
        }
        // Filter FROM options to send for introspection to return additional config from a container registry.
        let deployFroms = self.configFiles.filter{$0.key == "FROM"}.map{$0.value}
        for deployFrom in deployFroms.reversed() {
            let from = try parseFrom(stringFrom: deployFrom)
            self.octaheFromHash[from.name!] = from
            self.octaheFrom.append(from.name!)
        }


        // Return only a valid config.
        let deployOptions = self.configFiles.filter{key, value in
            return ["RUN", "COPY", "ADD", "SHELL"].contains(key)
        }
        for deployOption in deployOptions {
            if ["COPY", "ADD"].contains(deployOption.key) {
                let addCopy = try parseAddCopy(stringAddCopy: deployOption.value)
                self.octaheDeploy.append((key: deployOption.key, value: addCopy))
            } else {
                self.octaheDeploy.append(
                    (
                        key: deployOption.key,
                        value: (
                            execute: deployOption.value,
                            chown: nil,
                            location: nil,
                            destination: nil,
                            from: nil
                        )
                    )
                )
            }
        }
        let exposes = self.configFiles.filter{$0.key == "EXPOSE"}
        for expose in exposes {
            let exposeParsed = try parseExpose(stringExpose: expose.value)
            self.octaheExposes.append((key: expose.key, value: exposeParsed))
        }

        let command = self.configFiles.filter{$0.key == "CMD"}.last
        self.octaheCommand = command?.value
        let entrypoint = self.configFiles.filter{$0.key == "ENTRYPOINT"}.last
        self.octaheEntrypoints = entrypoint?.value
        self.octaheEntrypointOptions = self.configFiles.filter{key, value in
            return ["HEALTHCHECK", "STOPSIGNAL", "SHELL"].contains(key)
        }

        // filter all TARGETS.
        var targets: Array<String> = []
        if parsedOptions.targets.count >= 1 {
            for target in parsedOptions.targets {
                let (target, viaHosts) = try parseTarget(stringTarget: target)
                viaLoad(viaHosts: viaHosts)
                self.octaheTargetHash[target.name!] = target
                targets.append(target.name!)
            }
        } else {
            let filteredTargets = self.configFiles.filter{$0.key == "TO"}
            for target in filteredTargets {
                let (target, viaHosts) = try parseTarget(stringTarget: target.value)
                viaLoad(viaHosts: viaHosts)
                self.octaheTargetHash[target.name!] = target
                targets.append(target.name!)
            }
        }
        self.octaheTargets = targets.chunked(into: parsedOptions.connectionQuota)
    }
}


func CoreRouter(parsedOptions:Octahe.Options, function:String) throws {
    print("Running function:", function)
    let Args = try ConfigParse(parsedOptions: parsedOptions)
    let conn = ExecuteSSH(cliParameters: parsedOptions, processParams: Args)

    if Args.octaheFrom.count > 0 {
        // TODO(zfeldstein): API call to inspect all known FROM instances
        for from in Args.octaheFrom {
            // For every entry in FROM, we should insert the layers into our deployment plan.
            // This logic may need to be in the ConfigParse struct?
            print(Args.octaheFromHash[from]!.name!)
            print(
                RouterError.NotImplemented(
                    message: "This is where introspection will be queued..."
                )
            )
        }
    }
    for targetGroup in Args.octaheTargets {
        print(
            RouterError.NotImplemented(
                message: "This will initialize a thread pool for the selected target group."
            ), targetGroup
        )
        // This is serial, but should be threaded.
        for target in targetGroup {
            try conn.connect(target: target)
            for deployItem in Args.octaheDeploy {
                try conn.deploy(deployItem: deployItem.value)
            }
            conn.serviceTemplate(
                command: Args.octaheCommand,
                entrypoint: Args.octaheEntrypoints,
                entrypointOptions: Args.octaheEntrypointOptions
            )
        }
        print(
            RouterError.NotImplemented(
                message: "This is where we connect to targets and validate the deployment solution, and build all of the required proxy config."
            )
        )
    }
    print("Successfully deployed.")
}
