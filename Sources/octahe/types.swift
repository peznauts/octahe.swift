//
//  types.swift
//  
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation

typealias TypeFrom = (platform: String?, image: String, name: String?)

typealias TypeTarget = (to: String, via: String?, escalate: String?, name: String)

typealias TypeExposes = (port: Int, nat: Int?, proto: String?)

typealias TypeEntrypointOptions = [(key: String, value: String)]

class TypeDeploy {
    let execute: String?
    let chown: String?
    var location: [String]?
    let destination: String?
    let from: String?
    let original: String
    let env: [String: String]?
    let user: String?
    let group: String?
    let escalate: String?
    let escalatePassword: String?
    let exposeData: TypeExposes?
    let workdir: String?

    init (execute: String? = nil, chown: String? = nil, location: [String]? = [], destination: String? = nil,
          from: String? = nil, original: String, env: [String: String]? = nil, user: String? = nil,
          group: String? = nil, escalate: String? = nil, escalatePassword: String? = nil,
          exposeData: TypeExposes? = nil, workdir: String? = nil) {
        self.execute = execute ?? nil
        self.chown = chown ?? nil
        self.location = location
        self.destination = destination ?? nil
        self.from = from ?? nil
        self.original = original
        self.env = env
        self.user = user
        self.group = group
        self.escalate = escalate
        self.escalatePassword = escalatePassword
        self.exposeData = exposeData
        self.workdir = workdir
    }
}
