//
//  mixin.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

import Spinner

let taskQueue = TaskOperations()

let targetQueue = TargetOperations()

let inspectionQueue = InspectionOperations()

enum RouterError: Error {
    case notImplemented(message: String)
    case failedExecution(message: String)
    case failedUnknown
}

func cliFinish(octaheArgs: ConfigParse, octaheSteps: Int) {
    let failedTargets = targetQueue.targetRecords.values.filter {$0.state == .failed}
    if failedTargets.count == octaheArgs.octaheTargetsCount {
        print("\nExecution Failed.\n")
    } else if failedTargets.count > 0 {
        print("\nExecution Degraded.\n")
    } else {
        print("\nSuccess.")
    }
    for degradedTarget in failedTargets {
        print(
            """
            [-] \(degradedTarget.target.name) - failed step \(degradedTarget.failedStep!) / \(octaheSteps)
                \(degradedTarget.failedTask!)
            """
        )
    }
    let successTargets = targetQueue.targetRecords.values.filter {$0.state == .available}.count
    if successTargets > 0 {
        print("[+] Successfully deployed \(successTargets) targets")

    }
}

func taskRouter(parsedOptions: OctaheCLI.Options, function: ExecutionStates) throws {
    logger.debug("Running function: \(function)")

    let configFileURL = URL(fileURLWithPath: parsedOptions.configurationFiles.first!)
    let configDirURL = configFileURL.deletingLastPathComponent()
    let octaheArgs = try ConfigParse(parsedOptions: parsedOptions, configDirURL: configDirURL)

    if octaheArgs.octaheFrom.count > 0 {
        for from in octaheArgs.octaheFrom {
            let fromComponents = from.components(separatedBy: ":")
            let image = fromComponents.first
            var tag: String = "latest"
            if fromComponents.last != image {
                tag = fromComponents.last!
            }
            inspectionQueue.inspectionQueue.addOperation(
                InspectionOperationQuay(
                    containerImage: image!,
                    tag: tag
                )
            )
        }
        inspectionQueue.inspectionQueue.waitUntilAllOperationsAreFinished()
        for (_, value) in inspectionQueue.inspectionInComplete {
            let deployOptions = value.filter {key, _ in
                return ["RUN", "SHELL", "ARG", "ENV", "USER", "INTERFACE", "EXPOSE", "WORKDIR", "LABEL"].contains(key)
            }
            for deployOption in deployOptions.reversed() {
                octaheArgs.octaheDeploy.insert(try octaheArgs.deploymentCases(deployOption), at: 0)
            }
        }
    }

    if octaheArgs.octaheTargetHash.values.filter({$0.viaName != nil}).count > 0 {
        octaheArgs.octaheSshConfigFile = try localTempFile(content: parsedOptions.configurationFiles.first!)
        var sshViaData: [[String:Any]] = []
        for item in octaheArgs.octaheTargetHash.values {
            var itemData: [String:Any] = [:]
            itemData["name"] = item.name.sha1
            itemData["server"] = item.domain
            itemData["port"] = item.port ?? 22
            itemData["user"] = item.user ?? "root"
            itemData["key"] = parsedOptions.connectionKey
            if let via = item.viaName {
                itemData["config"] = octaheArgs.octaheSshConfigFile?.path
                itemData["via"] = via.sha1
            }
            sshViaData.append(itemData)
        }
        try sshRender(data: ["targets": sshViaData]).write(
            to: octaheArgs.octaheSshConfigFile!,
            atomically: true,
            encoding: String.Encoding.utf8
        )
    }
    defer {
        if let tempSshConfigFile = octaheArgs.octaheSshConfigFile {
            print("Running temporary file cleanup")
            try? FileManager.default.removeItem(at: tempSshConfigFile)
        }
    }
    if octaheArgs.octaheDeploy.count < 1 {
        let configFiles = parsedOptions.configurationFiles.joined(separator: " ")
        throw RouterError.failedExecution(
            message: "No steps found within provided Containerfiles: \(configFiles)"
        )
    }

    if function == .undeploy {
        let deployOptions =  octaheArgs.octaheDeploy.filter {key, _ in
            return ["ENTRYPOINT"].contains(key)
        }
        var undeploy: [(key: String, value: TypeDeploy)] = []
        for deployItem in deployOptions {
            undeploy.append(deployItem)
        }
        octaheArgs.octaheDeploy = undeploy
    }
    
    // The total calculated steps start at 0, so we take the total and subtract 1.
    let octaheSteps = octaheArgs.octaheDeploy.count - 1

    // Modify the default quota set using our CLI args.
    targetQueue.maxConcurrentOperationCount = parsedOptions.connectionQuota
    var allTaskOperations: [TaskOperation] = []
    for (index, deployItem) in octaheArgs.octaheDeploy.enumerated() {
        let taskOperation = TaskOperation(
            deployItem: deployItem,
            steps: octaheSteps,
            stepIndex: index,
            args: octaheArgs,
            options: parsedOptions,
            function: function
        )
        allTaskOperations.append(taskOperation)
    }

    taskQueue.taskQueue.addOperations(allTaskOperations, waitUntilFinished: true)
    cliFinish(octaheArgs: octaheArgs, octaheSteps: octaheSteps)
}
