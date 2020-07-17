//
//  types.swift
//
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation

import Logging

typealias TypeFrom = (platform: String?, image: String, name: String?)

typealias TypeExposes = (port: Int32, nat: Int32?, proto: String?)

typealias TypeEntrypointOptions = [(key: String, value: String)]

typealias TypeDeployCase = (key: String, value: TypeDeploy)

typealias TypeLogString = Logger.Message

class TypeTarget {
    var domain: String
    var port: Int32?
    var user: String?
    var viaName: String?
    var escalate: String?
    var name: String
    var key: URL?

    init(domain: String, port: Int32 = 22, user: String? = nil, viaName: String? = nil,
         escalate: String? = nil, name: String, key: String? = nil) {
        self.domain = domain
        self.port = port
        self.user = user
        self.viaName = viaName
        self.escalate = escalate
        self.name = name
        if let keyFile = key {
            self.key = URL(fileURLWithPath: keyFile)
        }
    }
}

class TypeDeploy {
    let execute: String?
    let chown: String?
    var location: [String]?
    let destination: String?
    let from: String?
    let original: String
    let env: [String: String]?
    let arg: [String: String]?
    let user: String?
    let group: String?
    let escalate: String?
    let escalatePassword: String?
    let exposeData: TypeExposes?
    let workdir: String?
    var fatalExec: Bool = true

    init (execute: String? = nil, chown: String? = nil, location: [String]? = [], destination: String? = nil,
          from: String? = nil, original: String, env: [String: String]? = nil, arg: [String: String]? = nil,
          user: String? = nil, group: String? = nil, escalate: String? = nil, escalatePassword: String? = nil,
          exposeData: TypeExposes? = nil, workdir: String? = nil) {
        self.execute = execute ?? nil
        self.chown = chown ?? nil
        self.location = location
        self.destination = destination ?? nil
        self.from = from ?? nil
        self.original = original
        self.env = env
        self.arg = arg
        self.user = user
        self.group = group
        self.escalate = escalate
        self.escalatePassword = escalatePassword
        self.exposeData = exposeData
        self.workdir = workdir
    }
}
