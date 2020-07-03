//
//  templateFile.swift
//
//
//  Created by Kevin Carter on 6/20/20.
//

import Foundation

import Stencil

let systemdService: String = """
[Unit]
Description={{ service_name }} service
Documentation={% for doc in documentation %}"{{ doc['item'] }}" {% endfor %}
After=network-online.target systemd-udev-settle.service

[Service]
Type=simple
{% if user %}
User={{ user }}
{% endif %}
{% if group %}
Group={{ group }}
{% endif %}
{% if kill_signal %}
KillSignal={{ kill_signal }}
{% endif %}
{% if workdir %}
WorkingDirectory={{ workdir }}
{% endif %}
Environment={% for env in environment %}"{{ env['item'] }}" {% endfor %}
RemainAfterExit=yes
ExecStart={{ shell }} "{{ service_command }}"
Restart=always
Slice=Octahe.slice
CPUAccounting=yes
BlockIOAccounting=yes
MemoryAccounting=yes
TasksAccounting=yes
PrivateTmp={{ private_tmp }}

[Install]
WantedBy=multi-user.target
"""

func systemdRender(data: [String: Any]) throws -> String {
    let environment = Environment()
    let rendered = try environment.renderTemplate(string: systemdService, context: data)
    let lines = rendered.strip.split { $0.isNewline }
    let result = lines.joined(separator: "\n")
    return result
}

let sshConfig: String = """
Host *
    GlobalKnownHostsFile /dev/null
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
    Compression no
    TCPKeepAlive yes
    VerifyHostKeyDNS no
    ForwardX11 no
    ControlMaster auto

{% for item in targets %}
Host {{ item['name'] }}
    HostName {{ item['server'] }}
    Port {{ item['port'] }}
    User {{ item['user'] }}
    IdentitiesOnly yes
    IdentityFile {{ item['key'] }}
{% if item['via'] %}    ProxyCommand ssh -F {{ item["config"] }} -W %h:%p {{ item['via'] }}{%   endif %}
{% endfor %}
"""

func sshRender(data: [String: Any]) throws -> String {
    let environment = Environment()
    return try environment.renderTemplate(string: sshConfig, context: data)
}
