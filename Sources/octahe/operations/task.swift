//
//  task.swift
//  
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation

import Spinner

enum TaskStates {
    case new, running, success, degraded, failed
}

class TaskRecord {
    let task: String
    let taskItem: TypeDeploy
    var state = TaskStates.new

    init(task: String, taskItem: TypeDeploy) {
        self.task = task
        self.taskItem = taskItem
    }
}

class TaskOperations {
    lazy var taskRecords: [Int: TaskRecord] = [:]
    lazy var taskQueue: OperationQueue = {
    var queue = OperationQueue()
        queue.name = "Task queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

class TaskOperation: Operation {
    let taskRecord: TaskRecord
    let deployItem: (key: String, value: TypeDeploy)
    let steps: Int
    let stepIndex: Int
    let args: ConfigParse
    let options: OctaheCLI.Options
    var printStatus: Bool = true
    var mySpinner: Spinner?
    var statusLineFull: String?
    var statusLine: String?
    let function: ExecutionStates

    init(deployItem: (key: String, value: TypeDeploy), steps: Int, stepIndex: Int,
         args: ConfigParse, options: OctaheCLI.Options, function: ExecutionStates) {
        self.function = function
        self.deployItem = deployItem
        self.steps = steps
        self.stepIndex = stepIndex
        self.args = args
        self.options = options
        if let taskRecordsLookup = taskQueue.taskRecords[stepIndex] {
            self.taskRecord = taskRecordsLookup
        } else {
            let taskRecordsLookup = TaskRecord(task: deployItem.key, taskItem: deployItem.value)
            taskQueue.taskRecords[stepIndex] = taskRecordsLookup
            self.taskRecord = taskQueue.taskRecords[stepIndex]!
        }
    }

    private func finishTask() {
        let degradedTargetStates = targetQueue.targetRecords.values.filter {$0.state == .failed}
        if degradedTargetStates.count == args.octaheTargets.count {
            if let spinner = self.mySpinner {
                spinner.failure(self.statusLineFull)
            }
            self.taskRecord.state = .failed
        } else if degradedTargetStates.count > 0 {
            if let spinner = self.mySpinner {
                spinner.warning(self.statusLineFull)
            }
        } else {
            if let spinner = self.mySpinner {
                spinner.succeed(self.statusLine)
            }
        }
        if let spinner = self.mySpinner {
            spinner.clear()
        }
    }

    private func queueTaskOperations() -> [TargetOperation] {
        var taskOperationsArray: [TargetOperation] = []
        for target in args.octaheTargets {
            if let targetData = args.octaheTargetHash[target] {
                let targetOperation = TargetOperation(
                    target: targetData,
                    args: args,
                    options: options,
                    taskIndex: stepIndex,
                    taskRecord: self.taskRecord,
                    function: self.function
                )
                // If this current operation has dependencies, add them to the target options too.
                for dependency in self.dependencies {
                    targetOperation.addDependency(dependency)
                }
                if targetQueue.targetRecords[target]?.state == .available {
                    if printStatus {
                        self.mySpinner = Spinner(.dots, self.statusLine ?? "Working")
                        if let spinner = self.mySpinner {
                            spinner.start()
                        }
                        printStatus = false
                    }
                    taskOperationsArray.append(targetOperation)
                }
            }
        }
        return taskOperationsArray
    }

    override func main() {
        let availableTargets = targetQueue.targetRecords.values.filter {$0.state == .available}
        if availableTargets.count == 0 && targetQueue.targetRecords.keys.count > 0 {
            return
        }
        self.statusLineFull = String(
            format: "Step \(stepIndex)/\(steps) : \(deployItem.key) \(deployItem.value.original)"
        )
        self.statusLine = statusLineFull?.trunc(length: 77)
        targetQueue.nodeQueue.addOperations(self.queueTaskOperations(), waitUntilFinished: true)
        self.finishTask()
    }
}
