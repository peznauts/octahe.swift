//
//  operations.swift
//  
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation


var targetRecords: [String: TargetRecord] = [:]
var taskRecords: [Int: TaskRecord] = [:]


enum TaskStates {
    case new, running, success, degraded, failed
}


enum TargetStates {
    case available, failed
}


class TaskRecord {
    let task: String
    let taskItem: typeDeploy
    var state = TaskStates.new

    init(task: String, taskItem: typeDeploy) {
        self.task = task
        self.taskItem = taskItem
    }
}


class TargetRecord {
    let target: typeTarget
    let conn: Execution
    var state = TargetStates.available
    var failedTask: String?
    var failedStep: Int?

    init(target: typeTarget, args: ConfigParse, options: octaheCLI.Options) throws {
        self.target = target
        if target.name == "localhost" {
            self.conn = ExecuteLocal(cliParameters: options, processParams: args)
        } else {
            self.conn = ExecuteSSH(cliParameters: options, processParams: args)

            let targetComponents = target.to.components(separatedBy: "@")
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
                    targetData: target
                )
            }
        }
        self.conn.environment = args.octaheArgs
    }
}


class OperationTask: Operation {
    let taskRecord: TaskRecord
    let deployItem: (key: String, value: typeDeploy)
    let steps: Int
    let stepIndex: Int
    let args: ConfigParse
    let options: octaheCLI.Options
    var printStatus: Bool = true

    init(deployItem: (key: String, value: typeDeploy), steps: Int, stepIndex: Int,
         args: ConfigParse, options: octaheCLI.Options) {
        self.deployItem = deployItem
        self.steps = steps
        self.stepIndex = stepIndex
        self.args = args
        self.options = options
        if let taskRecordsLookup = taskRecords[stepIndex] {
            self.taskRecord = taskRecordsLookup
        } else {
            let taskRecordsLookup = TaskRecord(task: deployItem.key, taskItem: deployItem.value)
            taskRecords[stepIndex] = taskRecordsLookup
            self.taskRecord = taskRecords[stepIndex]!
        }
    }

    override func main() {
        let availableTargets = targetRecords.values.filter{$0.state == .available}
        if availableTargets.count == 0 && targetRecords.keys.count > 0 {
            return
        }
        let targetQueue = NodeOperations(connectionQuota: options.connectionQuota)
        let statusLine = String(format: "Step \(stepIndex)/\(steps) : \(deployItem.key) \(deployItem.value.original)")
        for target in args.octaheTargets {
            if let targetData = args.octaheTargetHash[target] {
                let targetOperation = OperationTarget(
                    target: targetData,
                    args: args,
                    options: options,
                    taskIndex: stepIndex
                )
                if targetRecords[target]?.state == .available {
                    if printStatus {
                        print(statusLine)
                        printStatus = false
                    }
                    targetQueue.nodeQueue.addOperation(targetOperation)
                }
            }
        }
        targetQueue.nodeQueue.waitUntilAllOperationsAreFinished()
        let degradedTargetStates = targetRecords.values.filter{$0.state == .failed}
        if degradedTargetStates.count == args.octaheTargets.count {
            print(" --> Failed")
            self.taskRecord.state = .failed
        } else if degradedTargetStates.count > 0 {
            print(" --> Degraded")
        } else {
            print(" --> Done")
        }
    }
}


class OperationTarget: Operation {
    let targetRecord: TargetRecord
    let target: typeTarget
    let args: ConfigParse
    let options: octaheCLI.Options
    let task: TaskRecord
    let taskIndex: Int

    init(target: typeTarget, args: ConfigParse, options: octaheCLI.Options, taskIndex: Int) {
        self.target = target
        self.args = args
        self.options = options
        self.taskIndex = taskIndex
        self.task = taskRecords[taskIndex]!

        if let targetRecordsLookup = targetRecords[target.name] {
            self.targetRecord = targetRecordsLookup
        } else {
            let targetRecordsLookup = try! TargetRecord(target: target, args: args, options: options)
            targetRecords[target.name] = targetRecordsLookup
            self.targetRecord = targetRecords[target.name]!
        }
    }

    override func main() {
        if isCancelled {
            return
        }
        self.task.state = .running
        let conn = targetRecord.conn
        logger.debug("Executing: \(task.task)")
        do {
            if task.taskItem.execute != nil {
                if task.task == "SHELL" {
                    conn.shell = task.taskItem.execute!
                } else {
                    try conn.run(execute: task.taskItem.execute!)
                }
            } else if task.taskItem.destination != nil && task.taskItem.location != nil {
                try targetRecord.conn.copy(
                    base: args.configDirURL,
                    to: task.taskItem.destination!,
                    fromFiles: task.taskItem.location!
                )
            }
        } catch {
            task.state = .degraded
            self.targetRecord.failedStep = self.taskIndex
            self.targetRecord.failedTask = "\(error)"
            self.targetRecord.state = .failed
        }
        if task.state != .degraded {
            task.state = .success
        }

    }
}
