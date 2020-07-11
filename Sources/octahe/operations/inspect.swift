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

enum InspectionStates {
    case new, running, success, failed
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
            throw RouterError.failedExecution(message: "Auth request has failed. Run with debug for more information.")
        }
        return httpRes!.body
    }

    private func storeToken() throws {
        let body = try self.makeRequest(
            urlString: "/token?service=registry.docker.io&scope=repository:\(self.fullRepository!):pull"
        )
        let jsonData = String(describing: body).data(using: .utf8)!
        let jsonBody = try JSONDecoder().decode(DockerToken.self, from: jsonData)
        self.token = jsonBody.token
    }

    private func imageManafest() throws {
        try self.createClient(hostname: "registry-1.docker.io")
        self.headers.add(name: "Authorization", value: "Bearer " + self.token!)
        let body = try self.makeRequest(
            urlString: "/v2/\(self.fullRepository!)/manifests/\(self.containerTag)"
        )
        print(body)
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
