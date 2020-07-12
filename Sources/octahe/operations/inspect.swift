//
//  inspect.swift
//
//
//  Created by Kevin Carter on 7/3/20.
//

import Foundation

import HTTP

struct DockerToken: Codable {
    var token: String
}

struct DockerHistory: Codable {
    struct HistoryItem: Codable {
        var v1Compatibility: String
    }

    var history: [HistoryItem]
}

struct DockerContainerConfig: Codable {
    struct CmdItem: Codable {
        // swiftlint:disable identifier_name
        var Cmd: [String]
    }
    // swiftlint:disable identifier_name
    var container_config: CmdItem
}

class InspectionRecord {
    var layerId: String?
    let name: String
    var items: [Substring] = []

    init(name: String) {
        self.name = name
    }
}

class Inspection {
    var containerImage: String?
    var containerTag: String = "latest"
    var containerRepo: String = "library"
    var fullRepository: String?
    var inspectionRecord: InspectionRecord?
    let requestQueue: MultiThreadedEventLoopGroup
    var client: HTTPClient?
    var token: String?
    var headers: HTTPHeaders = .init()
    let decoder: JSONDecoder = JSONDecoder()
    var fatalFrom: Bool = false

    init() {
        self.requestQueue = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    private func createClient(hostname: String = "auth.docker.io") throws {
        self.client = try HTTPClient.connect(scheme: .https, hostname: hostname, on: self.requestQueue).wait()
    }

    private func makeRequest(urlString: String) throws -> HTTPBody {
        var httpReq = HTTPRequest(
            method: .GET,
            url: urlString,
            headers: self.headers
        )
        logger.debug("URL: \(httpReq.url)")
        httpReq.contentType = .json
        let httpRes = try self.client?.send(httpReq).wait()
        guard httpRes!.status == .ok else {
            logger.debug("HTTP HEADERS: \(httpRes!.headers)")
            logger.debug("HTTP STATUS: \(httpRes!.status)")
            logger.debug("HTTP BODY: \(httpRes!.body)")
            throw RouterError.failedExecution(
                message: "Auth request has failed. Run with debug for more information."
            )
        }
        return httpRes!.body
    }

    private func jsonData(body: HTTPBody) -> Data {
        return String(describing: body).data(using: .utf8)!
    }

    private func storeToken() throws {
        let jsonData = self.jsonData(
            body: try self.makeRequest(
                urlString: "/token?service=registry.docker.io&scope=repository:\(self.fullRepository!):pull"
            )
        )
        let jsonBody = try decoder.decode(DockerToken.self, from: jsonData)
        self.token = jsonBody.token
    }

    private func imageManafest() throws {
        try self.createClient(hostname: "registry-1.docker.io")
        self.headers.add(name: "Authorization", value: "Bearer " + self.token!)
        let jsonData = self.jsonData(
            body: try self.makeRequest(
                urlString: "/v2/\(self.fullRepository!)/manifests/\(self.containerTag)"
            )
        )
        let historyItems = try decoder.decode(DockerHistory.self, from: jsonData)
        for historyItem in historyItems.history {
            let cmdItem = try decoder.decode(
                DockerContainerConfig.self, from: historyItem.v1Compatibility.data(using: .utf8)!
            )
            let cmdString = cmdItem.container_config.Cmd.joined(separator: " ").strip
            if !cmdString.isEmpty {
                let cmdGroup = cmdString.groups(
                    for: "(?:(?:.*nop\\))|(?:.*\\/.+-c\\s))(\\w.+|\\W.+)"
                ).first!.last!.strip
                if allSupportedVerbs.contains(where: cmdGroup.hasPrefix) {
                    if ["ADD", "COPY"].contains(where: cmdGroup.hasPrefix) {
                        logger.warning(
                            "FROM instruction is using COPY/ADD. This will be ommitted in the inserted instructions."
                        )
                        logger.warning("Omitting: \(cmdGroup)")
                    } else {
                        self.inspectionRecord?.items.append(Substring(cmdGroup))
                    }
                } else {
                    let runCmd: Substring
                    switch self.fatalFrom {
                    case true:
                        logger.debug("Instruction being added as fatal")
                        runCmd = "RUN \(cmdGroup)"
                    default:
                        runCmd = "RUN \(cmdGroup) || true"
                    }
                    self.inspectionRecord?.items.append(runCmd)
                }
            }
        }
    }

    public func imageParser(fromImage: String) {
        self.inspectionRecord = InspectionRecord(name: fromImage)

        logger.info("Parsing \(fromImage)")
        let fromComponents = fromImage.components(separatedBy: ":")
        if fromComponents.last != self.containerTag {
            self.containerTag = fromComponents.last!
        }
        self.containerImage = fromComponents.first!
        let imageComponents = self.containerImage!.components(separatedBy: "/")
        if imageComponents.first != self.containerImage {
            self.containerRepo = imageComponents.first!
            self.containerImage = imageComponents.last!
        }
        self.fullRepository = "\(self.containerRepo)/\(self.containerImage!)"
    }

    public func main() throws {
        try self.createClient()
        try self.storeToken()
        try self.imageManafest()
    }
}
