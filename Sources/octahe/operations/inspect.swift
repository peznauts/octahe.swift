//
//  task.swift
//
//
//  Created by Kevin Carter on 6/19/20.
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
    let imageURL: URL
    let headers: HTTPHeaders = ["Accept": "application/json"]
    var debug: Bool = false

    func runManifestsRequest() -> DataRequest {
        let manifestRequest = AF.request(self.imageURL, method: .get, headers: self.headers)
        .validate(statusCode: 200..<300)
        .validate(contentType: ["application/json"])
        .responseJSON(queue: utilityQueue) { (response) in
            switch response.result {
            case .success(let value):
                if let dictionary = value as? [String: Any] {
                    if let tags = dictionary["tags"] as? [String: Any] {
                        if let tag = tags[self.containerTag] as? [String: Any] {
                            let manifestDigest = tag["manifest_digest"]
                            self.inspectionRecords.layerId = manifestDigest as? String
                            self.runManifestRequest()
                        }
                    }
                }
                if self.debug {
                    debugPrint(response)
                }
            case .failure(let error):
                print("Image manifest not found: \(error)")
            }
        }
        return manifestRequest
    }

    private func parseLayers(layers: [Any]) {
        let cmdAnchor: String = "/bin/sh -c"
        for layer in layers {
            if let itemDictionary = layer as? [String: Any] {
                if let item = itemDictionary["command"] as? [String] {
                    if item.first!.starts(with: cmdAnchor) {
                        var stringItem = item.first
                        stringItem = stringItem!.replacingOccurrences(of: cmdAnchor, with: "").strip
                        if (stringItem?.starts(with: "#(nop)"))! {
                            stringItem = stringItem!.replacingOccurrences(of: "#(nop)", with: "").strip
                        } else {
                            stringItem = "RUN " + stringItem!
                        }
                        if let strippedItem = stringItem {
                            self.inspectionRecords.items.append(Substring(strippedItem))
                        }
                    }
                }
            }
        }
    }

    func runManifestRequest() {
        let imageManifest = self.imageURL.appendingPathComponent("manifest/\(inspectionRecords.layerId!)")

        AF.request(imageManifest, method: .get, headers: self.headers)
        .responseJSON(queue: utilityQueue) { (response) in
            switch response.result {
            case .success(let value):
                if let dictionary = value as? [String: Any] {
                    if let layers = dictionary["layers"] as? [Any] {
                        self.parseLayers(layers: layers)
                    }
                }
                if self.debug {
                    debugPrint(response)
                }
            case .failure(let error):
                print("Manifest layer processing error: \(error)")
            }
        }
    }

    override func main() {
        // we need a timeout here, and better flow control.
        let requestManifests = self.runManifestsRequest()
        while requestManifests.response == nil {
            sleep(1)
        }
        let fileParser = FileParser()
        fileParser.lineParser(lines: self.inspectionRecords.items)
        inspectionQueue.inspectionInComplete[self.containerImage] = fileParser.configOptions
    }

    init(containerImage: String, tag: String) {
        self.containerImage = containerImage
        self.containerTag = tag
        let baseURL = URL(string: "https://quay.io/api/v1/repository")!
        self.imageURL = baseURL.appendingPathComponent(containerImage)
        self.inspectionRecords = InspectionRecord(name: imageURL.lastPathComponent)
    }
}
