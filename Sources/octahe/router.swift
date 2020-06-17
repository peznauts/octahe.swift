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
    var octaheTargetsCount: Int = 0
    var octaheDeploy: [(key: String, value: typeDeploy)] = []
    var octaheExposes: [(key: String, value: typeExposes)] = []
    let octaheCommand: String?
    let octaheEntrypoints: String?
    let octaheEntrypointOptions: typeEntrypointOptions
    var octaheLocal: Bool = false

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
        self.octaheTargetsCount = targets.count
        if let index = targets.firstIndex(of: "localhost") {
            targets.remove(at: index)
            self.octaheLocal = true
        }
        self.octaheTargets = targets.chunked(into: parsedOptions.connectionQuota)
    }
}


func connectionRunner(statusLine: String, printStatus: Bool, deployItem: (key: String, value: typeDeploy),
                      step: Int, conn: Execution) -> Bool {
    do {
        if deployItem.value.execute != nil {
            if printStatus {
                print(statusLine, "\(deployItem.key) \(deployItem.value.execute!)")
            }
            if deployItem.key == "SHELL" {
                conn.shell = deployItem.value.execute!
            } else {
                try conn.run(execute: deployItem.value.execute!)
            }
        } else if deployItem.value.destination != nil && deployItem.value.location != nil {
            if printStatus {
                let filesStatus = deployItem.value.location?.joined(separator: " ")
                print(statusLine, "COPY or ADD \(filesStatus!) \(deployItem.value.destination!)")
            }
            try conn.copy(to: deployItem.value.destination!, fromFiles: deployItem.value.location!)
        }
    } catch {
        return false
    }
    if printStatus {
        print(" ---> done")
    }
    return true
}


func sshConnect(Args: ConfigParse, parsedOptions: Octahe.Options, steps: Int) throws -> [(target: String, step: Int)] {
    var runnerStatus: Bool
    var failedTargets: [String] = []
    var degradedTargets: [(target: String, step: Int)] = []
    let conn = ExecuteSSH(cliParameters: parsedOptions, processParams: Args)
    conn.environment = Args.octaheArgs
    for (index, deployItem) in Args.octaheDeploy.enumerated() {
        var printStatus: Bool = true
        let statusLine = String(format: "Step \(index)/\(steps) :")
        for targetGroup in Args.octaheTargets {
            // For every target group we should initialize a thread pool.
            for target in targetGroup {
                if failedTargets.contains(target) {
                    continue
                }

                let targetData = Args.octaheTargetHash[target]!
                let targetComponents = targetData.to.components(separatedBy: "@")
                if targetComponents.count > 1 {
                    conn.user = targetComponents.first!
                }
                let serverPort = targetComponents.last!.components(separatedBy: ":")
                if serverPort.count > 1 {
                    conn.server = serverPort.first!
                    conn.port = serverPort.last!
                } else {
                    conn.server = serverPort.first!
                }
                if !conn.port.isInt {
                    throw RouterError.FailedConnection(
                        message: "Connection never attempted because the port is not an integer.",
                        targetData: targetData
                    )
                }
                try conn.connect(target: target)

                runnerStatus = connectionRunner(
                    statusLine: statusLine,
                    printStatus: printStatus,
                    deployItem: deployItem,
                    step: index,
                    conn: conn
                )
                printStatus = false
                if !runnerStatus {
                    degradedTargets.append((target: target, step: index))
                    failedTargets.append(target)  // this should be revised when we have a real thread pool
                }
            }
        }
    }
    return degradedTargets
}


func localConnect(Args: ConfigParse, parsedOptions: Octahe.Options, steps: Int) throws -> [(target: String, step: Int)] {
    var runnerStatus: Bool
    var degradedTargets: [(target: String, step: Int)] = []
    let conn = ExecuteShell(cliParameters: parsedOptions, processParams: Args)
    conn.environment = Args.octaheArgs
    for (index, deployItem) in Args.octaheDeploy.enumerated() {
        var printStatus: Bool = true
        let statusLine = String(format: "Step \(index)/\(steps) :")
        runnerStatus = connectionRunner(
            statusLine: statusLine,
            printStatus: printStatus,
            deployItem: deployItem,
            step: index,
            conn: conn
        )
        printStatus = false
        if !runnerStatus {
            degradedTargets.append((target: "localhost", step: index))
            return degradedTargets
        }
    }
    return degradedTargets
}


func taskRouter(parsedOptions:Octahe.Options, function:String) throws {
    print("Running function:", function)

    let Args = try ConfigParse(parsedOptions: parsedOptions)
    if Args.octaheFrom.count > 0 {
        // TODO(zfeldstein): API call to inspect all known FROM instances
        for from in Args.octaheFrom {
            // For every entry in FROM, we should insert the layers into our deployment plan.
            // This logic may need to be in the ConfigParse struct?
            print(
                RouterError.NotImplemented(
                    message: "This is where introspection will be queued for image: " + Args.octaheFromHash[from]!.name!
                )
            )
        }
    }
    print(
        RouterError.NotImplemented(
            message: "This is where we connect to targets and validate the deployment solution, and build all of the required proxy config."
        )
    )
    let steps = Args.octaheDeploy.count - 1
    var degradedTargets = try sshConnect(Args: Args, parsedOptions: parsedOptions, steps: steps)

    if Args.octaheLocal {
        print("Running octahe commands locally.")
        let degradedLocal = try localConnect(Args: Args, parsedOptions: parsedOptions, steps: steps)
        degradedTargets.append(contentsOf: degradedLocal)
    }

    if degradedTargets.count > 0 {
        if degradedTargets.count < Args.octaheTargetsCount {
            print("Deployment completed, but was degraded.")
        } else {
            print("Deployment failed.")
        }
        print("Degrated hosts:")
        for degradedTarget in degradedTargets {
            print("[-] \(degradedTarget.target) - failed step \(degradedTarget.step)/\(steps)")
        }
    } else {
        print("Successfully deployed.")
    }
}
