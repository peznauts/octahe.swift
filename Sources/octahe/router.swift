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
    let octaheFrom: Array<String>
    let octaheTargets: [(key: String, value: String)]
    let octaheDeploy: [(key: String, value: String)]
    let octaheExposes: [(key: String, value: String)]
    let octaheCommand: (key: String, value: String)?
    let octaheEntrypoints: (key: String, value: String)?
    let octaheEntrypointOptions: [(key: String, value: String)]

    init(parsedOptions: Octahe.Options) throws {
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
        self.octaheFrom = self.configFiles.filter{$0.key == "FROM"}.map{$0.value}
        // TODO(zfeldstein): API call to inspect all known FROM instances
        if self.octaheFrom.count > 0 {
            print(RouterError.NotImplemented(message: "This is where introspection will be queued..."))
        }

        // filter all TARGETS.
        self.octaheTargets = self.configFiles.filter{$0.key == "TO"}
        if  self.octaheTargets.count < 1 {
            throw(RouterError.NoTargets(message: "No Targets provided."))
        } else {
            print(RouterError.NotImplemented(message: "This is where we connect to targets and validate the deployment solution."))
        }

        // Return only a valid config.
        self.octaheDeploy = self.configFiles.filter{key, value in
            return ["RUN", "COPY", "ADD"].contains(key)
        }
        self.octaheExposes = self.configFiles.filter{$0.key == "EXPOSE"}
        self.octaheCommand = self.configFiles.filter{$0.key == "CMD"}.last
        self.octaheEntrypoints = self.configFiles.filter{$0.key == "ENTRYPOINT"}.last
        self.octaheEntrypointOptions = self.configFiles.filter{key, value in
            return ["HEALTHCHECK", "STOPSIGNAL", "SHELL"].contains(key)
        }
    }
}


func CoreRouter(parsedOptions:Octahe.Options, function:String) throws {
    print("Running function:", function)
    let octaheArgs = try ConfigParse(parsedOptions: parsedOptions)
    // Retried struct vars just to make sure its working.
    print(octaheArgs.octaheArgs as Any)
    print("Successfully deployed.")
}
