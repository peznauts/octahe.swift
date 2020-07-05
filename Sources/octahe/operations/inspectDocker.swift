// ////
// ////  inspectDocker.swift
// ////
// ////
// ////  Created by Kevin Carter on 7/3/20.
// ////
// ///// DOCKER HUB
// ///// curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:tripleomaster/centos-binary-base:pull"
// ///// curl -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/tripleomaster/centos-binary-base/manifests/current-tripleo
// //
// ///// repo = first item in image name when there's /
// ///// image name item after slash before :
// ///// tag name after :
// ////

// import Foundation

// class InspectionOperationDocker: InspectionOperation {
//     override init(containerImage: String, tag: String, debug: Bool) {
//         super.init(containerImage: containerImage, tag: tag, debug: debug)
//         let baseURL = URL(string: "https://quay.io/api/v1/repository")!
//         self.imageURL = baseURL.appendingPathComponent(containerImage)
//         self.inspectionRecords = InspectionRecord(name: imageURL.lastPathComponent)

//     }

//     private func parseLayers(layers: [Any]) {
//     }

//     override func runManifestsRequest() {
//     }

//     func runLayerRequest() {
//     }
// }
