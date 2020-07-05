//
//  inspect.swift
//  
//
//  Created by Kevin Carter on 7/3/20.
//

import Foundation

import Alamofire

enum InspectionStates {
    case new, running, success, failed
}

let utilityQueue = DispatchQueue.global(qos: .utility)

class InspectionOperations {
    lazy var inspectionInComplete: [String: TypeEntrypointOptions] = [:]
    lazy var inspectionInProgress: [IndexPath: Operation] = [:]
    lazy var inspectionQueue: OperationQueue = {
    var queue = OperationQueue()
        queue.name = "Inspection queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

class InspectionRecord {
    var layerId: String?
    let name: String
    var items: [Substring] = []

    init(name: String) {
        self.name = name
    }
}


class InspectionOperation: Operation {
    let containerImage: String
    let containerTag: String
    var inspectionRecords: InspectionRecord
    var imageURL: URL = URL(string: "https://registry.hub.docker.com/v2")!
    var headers: HTTPHeaders = ["Accept": "application/json"]
    let debug: Bool
    
    init(containerImage: String, tag: String, debug: Bool = false) {
        self.inspectionRecords = InspectionRecord(name: imageURL.lastPathComponent)
        self.containerImage = containerImage
        self.containerTag = tag
        self.debug = debug
    }

    func waitForResponse() {
        let group = DispatchGroup()
        group.wait()
    }

    func runManifestsRequest() {
        preconditionFailure("This method is not supported")
    }

    override func main() {
        logger.debug("Processing image API for: \(self.containerImage) tag: \(self.containerTag) url: \(imageURL.path)")
        // we need a timeout here, and better flow control.
        self.runManifestsRequest()
        self.waitForResponse()
        let fileParser = FileParser()
        fileParser.lineParser(lines: self.inspectionRecords.items)
        inspectionQueue.inspectionInComplete[self.containerImage] = fileParser.configOptions
    }
}
