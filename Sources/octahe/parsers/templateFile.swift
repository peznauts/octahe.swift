//
//  templateFile.swift
//  
//
//  Created by Kevin Carter on 6/20/20.
//

import Foundation

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
    throw RouterError.notImplemented(message: "Mustash is not available on linux")
}
