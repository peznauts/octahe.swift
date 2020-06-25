//
//  task.swift
//
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation

enum InspectionStates {
    case new, running, success, failed
}

var inspectionRecords: [String: String] = [:]  // should be changed once we can define the inspect data structure.

class InspectionRecord {}

class InspectionOperation: Operation {}
