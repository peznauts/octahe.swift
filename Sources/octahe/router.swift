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
}

func CoreRouter(parsedOptions:Octahe.Options, function:String) throws {
    let configFiles = try FileParser.buildRawConfigs(
        files: parsedOptions.configurationFiles
    )

    print("Running function:", function)
    // Collect the ARG options, they could be used in TO or FROM

    // TODO(cloudnull): The follow args need to be rendered and added to a CONSTANT
    // Sourced from remote target at runtime
    //    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
    //    TARGETOS - OS component of TARGETPLATFORM
    //    TARGETARCH - architecture component of TARGETPLATFORM
    //    TARGETVARIANT - variant component of TARGETPLATFORM\
    // Sourced from local machine
    //    BUILDPLATFORM - platform of the node performing the build.
    //    BUILDOS - OS component of BUILDPLATFORM
    //    BUILDARCH - architecture component of BUILDPLATFORM
    //    BUILDVARIANT - variant component of BUILDPLATFORM

    // TODO(cloudnull): ARG/ENV/LABEL format has three types: k=v, k v, k.
    //                  Additionally multiple arguments can be set on a single line.
    let octaheLabels = configFiles.filter{$0.key == "LABEL"}.map{$0.value}.reduce(into: [String: String]()) {
        let argArray = $1.split(separator: "=", maxSplits: 1)
        if let key = argArray.first, let value = argArray.last {
            let cleanedKey = String(key).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedValue = String(value).trimmingCharacters(in: .whitespacesAndNewlines)
            $0[cleanedKey] = cleanedValue
        }
    }
    print(octaheLabels)

    let octaheArgs = configFiles.filter{$0.key == "ARG" || $0.key == "ENV"}.map{$0.value}.reduce(into: [String: String]()) {
        // This needs work, the ARG/ENV/LABEL format has three types: k=v, k v, k.
        // Additionally multiple arguments can be set on a single line.
        let argArray = $1.split(separator: "=", maxSplits: 1)
        if let key = argArray.first, let value = argArray.last {
            let cleanedKey = String(key).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedValue = String(value).trimmingCharacters(in: .whitespacesAndNewlines)
            $0[cleanedKey] = cleanedValue
        }
    }
    print(octaheArgs)

    // Filter FROM options to send for introspection to return additional config from a container registry.
    let octaheFrom = configFiles.filter{$0.key == "FROM"}.map{$0.value}
    if octaheFrom.count > 0 {
        throw(RouterError.NotImplemented(message: "This is where introspection will be queued..."))
    }

    // Filter all FROM options, they're not used any longer.
    let octaheVerbs = configFiles.filter{$0.key != "FROM"}

    // filter all TARGETS.
    let targets = octaheVerbs.filter{$0.key == "TO"}
    if targets.count < 1 {
        throw(RouterError.NoTargets(message: "No Targets provided."))
    }

    // Return only a valid config.
    let octaheConfig = octaheVerbs.filter{$0.key != "TO"}
    print(octaheConfig)
    print("Successfully deployed.")
}
