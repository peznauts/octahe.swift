//
//  target.swift
//  
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation


enum TargetStates {
    case available, failed
}


var targetRecords: [String: TargetRecord] = [:]


class TargetRecord {
    let target: typeTarget
    let conn: Execution
    var state = TargetStates.available
    var failedTask: String?
    var failedStep: Int?

    init(target: typeTarget, args: ConfigParse, options: octaheCLI.Options) throws {
        self.target = target

        if options.dryRun {
            self.conn = ExecuteEcho(cliParameters: options, processParams: args)
        } else {
            switch target.name {
            case "localhost":
                self.conn = ExecuteLocal(cliParameters: options, processParams: args)
            default:
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
        }

        self.conn.target = String(target.name)

        if let escalate = self.target.escalate {
            self.conn.escalate = escalate
            if let password = options.escalatePassword {
                self.conn.escalatePassword = password
            }
        }
        // Probe the environment to set basic environment details.
        self.conn.probe()
    }
}


class TargetOperations {
    let maxConcurrentOperationCount: Int

    init(connectionQuota: Int) {
        maxConcurrentOperationCount = connectionQuota
    }

    lazy var nodesInProgress: [IndexPath: Operation] = [:]
    lazy var nodeQueue: OperationQueue = {
    var queue = OperationQueue()
        queue.name = "Node queue"
        queue.maxConcurrentOperationCount = self.maxConcurrentOperationCount
        return queue
    }()
}


class TargetOperation: Operation {
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
            switch task.task {
            case "SHELL":
                conn.shell = task.taskItem.execute!
            case "ENV", "ARG":
                if let env = task.taskItem.env {
                    conn.environment.merge(env) {
                        (_, second) in second
                    }
                }
            case "LABEL":
                if let env = task.taskItem.env {
                    for (key, value) in env {
                        conn.environment[key] = value
                    }
                }
            case "RUN":
                try conn.run(execute: task.taskItem.execute!)
            case "COPY", "ADD":
                try conn.copy(
                    base: args.configDirURL,
                    to: task.taskItem.destination!,
                    fromFiles: task.taskItem.location!
                )
            case "USER":
                conn.execUser = task.taskItem.user!
            case "EXPOSE":
                if let port = task.taskItem.exposeData?.port {
                    try conn.expose(
                        nat: task.taskItem.exposeData?.nat,
                        port: port,
                        proto: task.taskItem.exposeData?.proto
                    )
                }
            case "WORKDIR":
                conn.workdir = task.taskItem.workdir!
                conn.workdirURL = URL(fileURLWithPath: conn.workdir)
            case "CMD":
                conn.command = task.taskItem.execute!
            case "HEALTHCHECK":
                conn.healthcheck = task.taskItem.execute!
            case "STOPSIGNAL":
                conn.stopsignal = task.taskItem.execute!
            case "ENTRYPOINT":
                try conn.serviceTemplate(entrypoint: task.taskItem.execute!)
            default:
                throw RouterError.NotImplemented(message: "The task type \(task.task) is not supported.")
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
