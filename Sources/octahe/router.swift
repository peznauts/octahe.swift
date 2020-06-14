//
//  mixin.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation


enum RouterError: Error {
    case NoTargets(message: String)
    case NotImplemented(message: String)
    case MatchRegexError(message: String)
}


struct ConfigParse {
    let configFiles: [(key: String, value: String)]
    var runtimeArgs: Dictionary<String, String>
    var octaheArgs: Dictionary<String, String>
    let octaheLabels: Dictionary<String, String>
    var octaheFrom: Array<AnyObject> = []
    var octaheTargets: [(to: String, via: String?, escalate: String?, name: String?)] = []
    var octaheDeploy: Array<AnyObject> = []
    var octaheExposes: Array<AnyObject> = []
    let octaheCommand: (key: String, value: String)?
    let octaheEntrypoints: (key: String, value: String)?
    let octaheEntrypointOptions: [(key: String, value: String)]

    init(parsedOptions: Octahe.Options) throws {
        func parseTarget(stringTarget: String) -> (to: String, via: String?, escalate: String?, name: String?) {
            // Target parse string argyments and return a tuple.
            let arrayTarget = stringTarget.components(separatedBy: " ")
            let parsedTarget = try! OptionsTarget.parse(arrayTarget)
            return (
                to: parsedTarget.target,
                via: parsedTarget.via ?? "localhost",
                escalate: parsedTarget.escalate,
                name: parsedTarget.name ?? parsedTarget.target
            )
        }

        func parseAddCopy(stringAddCopy: String) -> (chown: String?, location: String, destination: String, from: String?) {
            // Target parse string argyments and return a tuple.
            let arrayCopyAdd = stringAddCopy.components(separatedBy: " ")
            let parsedCopyAdd = try! OptionsAddCopy.parse(arrayCopyAdd)
            return (
                chown: parsedCopyAdd.chown,
                location: parsedCopyAdd.location,
                destination: parsedCopyAdd.destination,
                from: parsedCopyAdd.from
            )
        }

        func parseFrom(stringFrom: String) -> (platform: String?, image: String, name: String?) {
            // Target parse string argyments and return a tuple.
            let arrayFrom = stringFrom.components(separatedBy: " ")
            let parsedFrom = try! OptionsFrom.parse(arrayFrom)
            return (
                platform: parsedFrom.platform,
                image: parsedFrom.image,
                name: parsedFrom.name
            )
        }

        func parseExpose(stringExpose: String) -> (port: String, nat: Substring?, proto: String?) {
            // Target parse string argyments and return a tuple.
            let arrayExpose = stringExpose.components(separatedBy: " ")
            let parsedExpose = try! OptionsExpose.parse(arrayExpose)
            let natPort = parsedExpose.nat?.split(separator: "/", maxSplits: 1)
            let proto = natPort?[1] ?? "tcp"
            return (
                port: parsedExpose.port,
                nat: natPort?.first,
                proto: proto.lowercased()
            )
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
        for deployFrom in deployFroms {
            let from = parseFrom(stringFrom: deployFrom)
            self.octaheFrom.append((key: "FROM", value: from) as AnyObject)
        }

        // filter all TARGETS.
        if parsedOptions.targets.count >= 1 {
            for target in parsedOptions.targets {
                let target = parseTarget(stringTarget: target)
                self.octaheTargets.append(target)
            }
        } else {
            let filteredTargets = self.configFiles.filter{$0.key == "TO"}
            for target in filteredTargets {
                let target = parseTarget(stringTarget: target.value)
                self.octaheTargets.append(target)
            }
        }

        // Return only a valid config.
        let deployOptions = self.configFiles.filter{key, value in
            return ["RUN", "COPY", "ADD", "SHELL"].contains(key)
        }
        for deployOption in deployOptions {
            if ["COPY", "ADD"].contains(deployOption.key) {
                let addCopy = parseAddCopy(stringAddCopy: deployOption.value)
                self.octaheDeploy.append((key: deployOption.key, value: addCopy) as AnyObject)
            } else {
                self.octaheDeploy.append(deployOption as AnyObject)
            }

        }
        let exposes = self.configFiles.filter{$0.key == "EXPOSE"}
        for expose in exposes {
            let exposeParsed = parseExpose(stringExpose: expose.value)
            self.octaheExposes.append((key: expose.key, value: exposeParsed) as AnyObject)
        }

        self.octaheCommand = self.configFiles.filter{$0.key == "CMD"}.last
        self.octaheEntrypoints = self.configFiles.filter{$0.key == "ENTRYPOINT"}.last
        self.octaheEntrypointOptions = self.configFiles.filter{key, value in
            return ["HEALTHCHECK", "STOPSIGNAL", "SHELL"].contains(key)
        }
    }
}


func CoreRouter(parsedOptions:Octahe.Options, function:String) throws {
    print("Running function:", function)
    let Args = try ConfigParse(parsedOptions: parsedOptions)

    if Args.octaheFrom.count > 0 {
        // TODO(zfeldstein): API call to inspect all known FROM instances
        print(
            RouterError.NotImplemented(
                message: "This is where introspection will be queued..."
            )
        )
    }
    print(
        RouterError.NotImplemented(
            message: "This is where we connect to targets and validate the deployment solution, and build all of the required proxy config."
        )
    )
    print(Args.octaheExposes)
    print("Successfully deployed.")
}
