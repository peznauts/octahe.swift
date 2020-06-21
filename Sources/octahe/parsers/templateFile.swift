//
//  templateFile.swift
//  
//
//  Created by Kevin Carter on 6/20/20.
//

import Foundation

import Mustache


let systemdService: String = """
[Unit]
Description={{service_name}} service

{{# documentation }}
Documentation={{ item }}
{{/ documentation }}

After=syslog.target network-online.target systemd-udev-settle.service

[Service]
Type=oneshot
User={{ user }}
Group={{ group }}

{{# environment }}
Environment="{{ item }}"
{{/ environment }}

[Install]
WantedBy=multi-user.target
"""


func systemdRender() throws {
    print(Bundle.main)
    let template = try Template(string: systemdService)
    let data = [
        "service_name": "Test Service1",
        "documentation": ["item": "This is where labels would go"],
        "type": "oneshot",
        "user": "root",
        "group": "root",
        "environment": ["item": "KEY=VALUE"]
        ] as [String : Any]
    let rendering = try template.render(data)
    let trimRendering = rendering.trimmingCharacters(in: .whitespacesAndNewlines)
    let lines = trimRendering.split { $0.isNewline }
    let result = lines.joined(separator: "\n")
    let filename = URL(fileURLWithPath: "/etc/systemd/system/output.txt")
    try result.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
    throw RouterError.NotImplemented(message: "Fuckyou")
}
