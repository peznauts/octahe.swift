// //
// //  inspectQuay.swift
// //
// //
// //  Created by Kevin Carter on 6/19/20.
// //
//
// import Foundation
//
// class InspectionOperationQuay: InspectionOperation {
//     override init(containerImage: String, tag: String, debug: Bool) {
//         super.init(containerImage: containerImage, tag: tag, debug: debug)
//         let baseURL = URL(string: "https://quay.io/api/v1/repository")!
//         self.imageURL = baseURL.appendingPathComponent(containerImage)
//         self.inspectionRecords = InspectionRecord(name: imageURL.lastPathComponent)
//
//     }
//
//     private func parseLayers(layers: [Any]) {
//         let cmdAnchor: String = "/bin/sh -c"
//         for layer in layers {
//             if let itemDictionary = layer as? [String: Any] {
//                 if let item = itemDictionary["command"] as? [String] {
//                     if item.first!.starts(with: cmdAnchor) {
//                         var stringItem = item.first
//                         stringItem = stringItem!.replacingOccurrences(of: cmdAnchor, with: "").strip
//                         if (stringItem?.starts(with: "#(nop)"))! {
//                             stringItem = stringItem!.replacingOccurrences(of: "#(nop)", with: "").strip
//                         } else {
//                             stringItem = "RUN " + stringItem!
//                         }
//                         if let strippedItem = stringItem {
//                             self.inspectionRecords.items.append(Substring(strippedItem))
//                         }
//                     }
//                 }
//             }
//         }
//     }
//
//     override func runManifestsRequest() {
//         AF.request(self.imageURL, method: .get, headers: self.headers)
//         .validate(statusCode: 200..<300)
//         .validate(contentType: ["application/json"])
//         .responseJSON(queue: utilityQueue) { (response) in
//             switch response.result {
//             case .success(let value):
//                 if let dictionary = value as? [String: Any] {
//                     if let tags = dictionary["tags"] as? [String: Any] {
//                         if let tag = tags[self.containerTag] as? [String: Any] {
//                             let manifestDigest = tag["manifest_digest"]
//                             self.inspectionRecords.layerId = manifestDigest as? String
//                             self.runLayerRequest()
//                         }
//                     }
//                 }
//                 if self.debug {
//                     debugPrint(response)
//                 }
//             case .failure(let error):
//                 logger.critical("Image manifest not found: \(error)")
//             }
//         }
//     }
//
//     func runLayerRequest() {
//         let imageManifest = self.imageURL.appendingPathComponent("manifest/\(inspectionRecords.layerId!)")
//         AF.request(imageManifest, method: .get, headers: self.headers)
//         .responseJSON(queue: utilityQueue) { (response) in
//             switch response.result {
//             case .success(let value):
//                 if let dictionary = value as? [String: Any] {
//                     if let layers = dictionary["layers"] as? [Any] {
//                         self.parseLayers(layers: layers)
//                     }
//                 }
//                 if self.debug {
//                     debugPrint(response)
//                 }
//             case .failure(let error):
//                 print("Manifest layer processing error: \(error)")
//             }
//         }
//     }
// }
