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
Description={{ service_name }} service
Documentation={{# documentation }}{{ item }} {{/ documentation }}
After=network-online.target systemd-udev-settle.service

[Service]
Type=simple
{{# user }}User={{ user }}{{/ user }}
{{# group }}Group={{ group }}{{/ group }}
{{# kill_signal }}KillSignal={{ kill_signal }}{{/ kill_signal }}
{{# workdir }}WorkingDirectory={{ workdir }}{{/ workdir }}
Environment={{# environment }}"{{ item }}" {{/ environment }}
RemainAfterExit=yes
ExecStart={{ shell }} "{{ service_command }}"
Restart=always

[Install]
WantedBy=multi-user.target
"""


func systemdRender(data: [String: Any]) throws -> String {
    let template = try Template(string: systemdService)
    let rendering = try template.render(data)
    let trimRendering = rendering.trimmingCharacters(in: .whitespacesAndNewlines)
    let lines = trimRendering.split { $0.isNewline }
    let result = lines.joined(separator: "\n")
    return result
}
