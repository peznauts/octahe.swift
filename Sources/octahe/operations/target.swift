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

private func viaArrayCreate(via: String, args: ConfigParse) -> [String] {
    var viaTarget = via
    var viaHosts: [String] = []
    while !["localhost", nil].contains(viaTarget) {
        let viaHost = args.octaheTargetHash[viaTarget] ?? nil
        guard viaHost == nil else {
            break
        }
        if let viaTo = viaHost?.domain {
            if let user = viaHost!.user {
                viaHosts.append("\(user)@\(viaTo)")
            } else {
                viaHosts.append(viaTo)
            }
            viaTarget = viaTo
        } else {
            break
        }
    }
    viaHosts.reverse()
    return viaHosts
}

class TargetRecord {
    let target: TypeTarget
    let conn: Execution
    var state = TargetStates.available
    var failedTask: String?
    var failedStep: Int?

    init(target: TypeTarget, args: ConfigParse, options: OctaheCLI.Options) {
        self.target = target
        if options.dryRun {
            self.conn = ExecuteEcho(cliParameters: options, processParams: args)
        } else {
            switch target.name {
            case "localhost":
                self.conn = ExecuteLocal(cliParameters: options, processParams: args)
            case let str where str.contains("/dev"):
                self.conn = ExecuteSerial(cliParameters: options, processParams: args)
            default:
                let connSsh: ExecuteSSH
                if let via = self.target.viaName {
                    let connSshVia = ExecuteSSHVia(cliParameters: options, processParams: args)
                    let viaHosts = viaArrayCreate(via: via, args: args)
                    connSshVia.connectionArgs.append("-J " + viaHosts.joined(separator: ","))
                    connSsh = connSshVia
                } else {
                    connSsh = ExecuteSSH(cliParameters: options, processParams: args)
                }

                connSsh.user = self.target.user ?? "root"
                connSsh.server = self.target.domain
                connSsh.port = self.target.port ?? 22

                try? connSsh.connect()
                self.conn = connSsh
            }
            self.conn.target = target.name
        }

        if let escalate = self.target.escalate {
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
    let target: TypeTarget
    let args: ConfigParse
    let options: OctaheCLI.Options
    let task: TaskRecord
    let taskIndex: Int

    init(target: TypeTarget, args: ConfigParse, options: OctaheCLI.Options, taskIndex: Int, taskRecord: TaskRecord) {
        self.target = target
        self.args = args
        self.options = options
        self.taskIndex = taskIndex
        self.task = taskRecord

        if let targetRecordsLookup = targetRecords[target.name] {
            self.targetRecord = targetRecordsLookup
        } else {
            let targetRecordsLookup = TargetRecord(target: target, args: args, options: options)
            targetRecords[target.name] = targetRecordsLookup
            self.targetRecord = targetRecords[target.name]!
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
            try self.targetRecord.conn.expose(
                nat: self.task.taskItem.exposeData?.nat,
                port: port,
                proto: self.task.taskItem.exposeData?.proto
            )
        }
    }

    private func caseEntryPoint() throws {
        if let cmd = args.octaheDeploy.filter({$0.key == "CMD"}).map({$0.value}).last {
            let entrypoint = "\(cmd.execute!) \(self.task.taskItem.execute!)"
            try self.targetRecord.conn.serviceTemplate(entrypoint: entrypoint)
        } else {
            try self.targetRecord.conn.serviceTemplate(entrypoint: self.task.taskItem.execute!)
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
        logger.debug("Executing: \(task.task)")
        do {
            try self.targetCases()
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
