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

class TargetRecord {
    let target: TypeTarget
    let conn: Execution
    var state = TargetStates.available
    var failedTask: String?
    var failedStep: Int?

    init(target: TypeTarget, args: ConfigParse, options: OctaheCLI.Options) {
        self.target = target
        switch options.dryRun {
        case true:
            logger.debug("Using the [echo] driver")
            self.conn = ExecuteEcho(cliParameters: options, processParams: args)
        default:
            switch target.name {
            case "localhost":
                logger.debug("Using the [local] driver")
                self.conn = ExecuteLocal(cliParameters: options, processParams: args)
            case let str where str.contains("/dev"):
                logger.debug("Using the [serial] driver")
                self.conn = ExecuteSerial(cliParameters: options, processParams: args)
            default:
                let connSsh: ExecuteSSH
                if self.target.viaName != nil {
                    logger.debug("Using the [sshVia] driver")
                    connSsh = ExecuteSSHVia(cliParameters: options, processParams: args)
                } else {
                    logger.debug("Using the [ssh] driver")
                    connSsh = ExecuteSSH(cliParameters: options, processParams: args)
                }

                connSsh.name = self.target.name
                connSsh.user = self.target.user ?? "root"
                connSsh.server = self.target.domain
                connSsh.port = self.target.port ?? 22

                try? connSsh.connect()
                self.conn = connSsh
            }
        }
        self.conn.target = target.name

        if let escalate = self.target.escalate {
            logger.debug("Setting an escallation password object")
            self.conn.escalate = escalate
            if let password = options.escalatePassword {
                self.conn.escalatePassword = password
            }
        }
        // Probe the environment to set basic environment details.
        try? self.conn.probe()
    }
}

class TargetOperations {
    var maxConcurrentOperationCount: Int

    init(connectionQuota: Int = 1) {
        maxConcurrentOperationCount = connectionQuota
    }
    lazy var targetRecords: [String: TargetRecord] = [:]
    lazy var nodeQueue: OperationQueue = {
    var queue = OperationQueue()
        queue.name = "Node queue"
        queue.maxConcurrentOperationCount = self.maxConcurrentOperationCount
        return queue
    }()
}

class TargetOperation: Operation {
    let targetRecord: TargetRecord
    let target: TypeTarget
    let args: ConfigParse
    let options: OctaheCLI.Options
    let task: TaskRecord
    let taskIndex: Int
    let function: ExecutionStates

    init(target: TypeTarget, args: ConfigParse, options: OctaheCLI.Options, taskIndex: Int, taskRecord: TaskRecord,
         function: ExecutionStates) {
        self.target = target
        self.args = args
        self.options = options
        self.taskIndex = taskIndex
        self.task = taskRecord
        self.function = function

        if let targetRecordsLookup = targetQueue.targetRecords[target.name] {
            self.targetRecord = targetRecordsLookup
        } else {
            let targetRecordsLookup = TargetRecord(target: target, args: args, options: options)
            targetQueue.targetRecords[target.name] = targetRecordsLookup
            self.targetRecord = targetQueue.targetRecords[target.name]!
        }
    }

    private func caseLabel() {
        if let env = self.task.taskItem.env {
            for (key, value) in env {
                self.targetRecord.conn.environment[key] = value
            }
        }
    }

    private func caseExpose() throws {
        if let port = self.task.taskItem.exposeData?.port {
            switch self.function {
            case .undeploy:
                try self.targetRecord.conn.exposeIptablesCreate(
                    nat: self.task.taskItem.exposeData?.nat,
                    port: port,
                    proto: self.task.taskItem.exposeData?.proto
                )
            default:
                try self.targetRecord.conn.exposeIptablesRemove(
                    nat: self.task.taskItem.exposeData?.nat,
                    port: port,
                    proto: self.task.taskItem.exposeData?.proto
                )
            }
        }
    }

    private func caseEntryPoint() throws {
        var entrypoint: String = self.task.taskItem.execute!
        if let cmd = args.octaheDeploy.filter({$0.key == "CMD"}).map({$0.value}).last {
            entrypoint = "\(cmd.execute!) \(entrypoint)"
        }
        switch self.function {
        case .undeploy:
            try self.targetRecord.conn.entrypointRemove(entrypoint: entrypoint)
        default:
            try self.targetRecord.conn.entrypointStart(entrypoint: entrypoint)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func targetCases() throws {
        switch self.task.task {
        case "SHELL":
            self.targetRecord.conn.shell = self.task.taskItem.execute!
        case "ENV", "ARG":
            if let env = self.task.taskItem.env {
                self.targetRecord.conn.environment.merge(env) {(_, second) in second}
            }
        case "LABEL":
            self.caseLabel()
        case "RUN":
            try self.targetRecord.conn.run(execute: self.task.taskItem.execute!)
        case "COPY", "ADD":
            try self.targetRecord.conn.copy(
                base: args.configDirURL,
                copyTo: self.task.taskItem.destination!,
                fromFiles: self.task.taskItem.location!,
                chown: self.task.taskItem.chown
            )
        case "USER":
            self.targetRecord.conn.execUser = self.task.taskItem.user!
        case "INTERFACE":
            self.targetRecord.conn.interface = self.task.taskItem.execute!
        case "EXPOSE":
            try self.caseExpose()
        case "WORKDIR":
            self.targetRecord.conn.workdir = self.task.taskItem.workdir!
            self.targetRecord.conn.workdirURL = URL(fileURLWithPath: self.targetRecord.conn.workdir)
            try self.targetRecord.conn.mkdir(workdirURL: self.targetRecord.conn.workdirURL)
        case "CMD":
            self.targetRecord.conn.command = self.task.taskItem.execute!
        case "HEALTHCHECK":
            self.targetRecord.conn.healthcheck = self.task.taskItem.execute!
        case "STOPSIGNAL":
            self.targetRecord.conn.stopsignal = self.task.taskItem.execute!
        case "ENTRYPOINT":
            try self.caseEntryPoint()
        default:
            throw RouterError.notImplemented(message: "The task type \(self.task.task) is not supported.")
        }
    }

    override func main() {
        if isCancelled {
            return
        }
        self.task.state = .running
        logger.debug("Executing: \(task.task) \(task.taskItem.original) on \(self.target.domain)")
        do {
            try self.targetCases()
        } catch let error {
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
