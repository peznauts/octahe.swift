//
//  mixin.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

enum RouterError: Error {
    case notImplemented(message: String)
    case failedExecution(message: String)
}

func cliFinish(octaheArgs: ConfigParse, octaheSteps: Int) {
    let failedTargets = targetRecords.values.filter {$0.state == .failed}
    for degradedTarget in failedTargets {
        print(
            """
            [-] \(degradedTarget.target.name) - failed step \(degradedTarget.failedStep!) / \(octaheSteps)
            \(degradedTarget.failedTask!)
            """
        )
    }
    if failedTargets.count > 0 {
        print("\nExecution Degraded.")
    } else if failedTargets.count == octaheArgs.octaheTargetsCount {
        print("\nExecution Failed.")
    } else {
        print("\nSuccess.")
    }
}

func taskRouter(parsedOptions: OctaheCLI.Options, function: String) throws {
    logger.debug("Running function: \(function)")

    let configFileURL = URL(fileURLWithPath: parsedOptions.configurationFiles.first!)
    let configDirURL = configFileURL.deletingLastPathComponent()
    let octaheArgs = try ConfigParse(parsedOptions: parsedOptions, configDirURL: configDirURL)
    // The total calculated steps start at 0, so we take the total and subtract 1.
    let octaheSteps = octaheArgs.octaheDeploy.count - 1

    if octaheArgs.octaheDeploy.count < 1 {
        let configFiles = parsedOptions.configurationFiles.joined(separator: " ")
        throw RouterError.failedExecution(
            message: "No steps found within provided Containerfiles: \(configFiles)"
        )
    }

    if octaheArgs.octaheFrom.count > 0 {

        for from in octaheArgs.octaheFrom {
            // For every entry in FROM, we should insert the layers into our deployment plan.
            // This logic may need to be in the ConfigParse struct?
            print(
                RouterError.notImplemented(
                    message: """
                             This is where introspection will be queued for image:
                             \(octaheArgs.octaheFromHash[from]!.name!)
                             """
                )
            )
        }
    }

    let taskQueue = TaskOperations()
    var lastOperation: Operation?
    for (index, deployItem) in octaheArgs.octaheDeploy.enumerated() {
        let taskOperation = TaskOperation(
            deployItem: deployItem,
            steps: octaheSteps,
            stepIndex: index,
            args: octaheArgs,
            options: parsedOptions
        )
        taskQueue.taskQueue.addOperation(taskOperation)
        if let operation = lastOperation {
            taskOperation.addDependency(operation)
        }
        lastOperation = taskOperation
    }
    taskQueue.taskQueue.waitUntilAllOperationsAreFinished()

    cliFinish(octaheArgs: octaheArgs, octaheSteps: octaheSteps)
}
