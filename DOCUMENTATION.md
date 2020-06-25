# General Documentation

### Deployment Configuration File

``` dockerfile
FROM python:latest
TO   --escalate=/usr/bin/sudo ${USER}@127.0.0.3:22
COPY index.html /opt/index.html
EXPOSE 7000
WORKDIR /opt
ENTRYPOINT python3 -m http.server 7000
```

#### OCI compatible verbs supported by Octahe.

* RUN
* COPY
* ADD
* SHELL
* ARG
* ENV
* USER
* EXPOSE
* WORKDIR
* LABEL
* CMD
* ENTRYPOINT
* STOPSIGNAL
* HEALTHCHECK

#### OCI Verbs that need to be implemented.

* FROM

#### Octahe specific verbs

* TO

##### TO

``` dockerfile
TO [--escalate=<path-to-binary>, --name=<string>, --via=<string>] [<address>:<port>@<user>, localhost, SERIALPORT]
```

The `TO` instruction initializes a new connection to a given target for subsequent instructions.
As such, a valid file must start with a `TO` instruction.

ARG is the only instruction that may precede `TO` in the file. See
[Understand how ARG and FROM interact](https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact).

`TO` can appear multiple times within a single file to create multiple connections to different targets.

Every `TO` entry requires three parts when connecting through SSH `<address>:<port>@<user>`.
The address can be an IP address or FQDN. The port will always be an integer. The user should
be the username required to access the given target.

The optional `--escalate` flag can be used to specify the means of privledge escallation. This
option requires the binary needed to perform a privledge escallation. Privledge escallation
may require a password, if this is the case, provide the password via the CLI by including
the `--escalate-pw` flag. Any password provided will only exist during runtime as an ARG.

``` dockerfile
FROM python:latest
TO   --escalate=/usr/bin/sudo ${USER}@127.0.0.1:22
COPY index.html /opt/index.html
EXPOSE 7000
WORKDIR /opt
ENTRYPOINT python3 -m http.server 7000
```

The optional `--name` flag can be used to specify a friendly "name" of a given node. If a name is
not provided, the system will assign the given target a "name" using a SHA1 sum.

``` dockerfile
FROM python:latest
TO   --escalate=/usr/bin/sudo --name=bastion0 ${USER}@127.0.0.1:22
COPY index.html /opt/index.html
EXPOSE 7000
WORKDIR /opt
ENTRYPOINT python3 -m http.server 7000
```

The optional `--via` flag can be used to specify the "bastion" used to transport a connection.
This provides the means to proxy a connection through another node into an environment. The syntax
for the `--via` optional argument follows the same mechanics as the `TO` verb; the `--via` argument
can accept the "name" of a given host.

> Because `--via` can take complete connection details, it is possible for a target to proxy commands
  through a node not being deployed to.

``` dockerfile
FROM python:latest
TO   --escalate=/usr/bin/sudo --name=bastion0 ${USER}@127.0.0.1:22  # First node named "bastion0"
TO   --escalate=/usr/bin/sudo --via=${USER}@127.0.0.1:22 --name=bastion1 ${USER}@127.0.0.2:22  # Connection via the first target using the connection details.
TO   --escalate=/usr/bin/sudo --via=bastion1 ${USER}@127.0.0.3:22  # Connection via the second target using the name.
COPY index.html /opt/index.html
EXPOSE 7000
WORKDIR /opt
ENTRYPOINT python3 -m http.server 7000
```

The `--via` flag can be used more than once within a given TO argument. When used more than once
the system will create an array which is FILO, allowing a node to poxy through multiple hosts.

``` dockerfile
FROM python:latest
TO   --escalate=/usr/bin/sudo --via=${USER}@127.0.0.1:22 --via=${USER}@127.0.0.1:22 ${USER}@127.0.0.3:22
COPY index.html /opt/index.html
EXPOSE 7000
WORKDIR /opt
ENTRYPOINT python3 -m http.server 7000
```

###### Notes about the serial port connection driver

* When connecting to a serial port, only binary data can be written to the device using the `COPY` verb, while
  the `COPY` verb requires both a file location and destination, the destination is omitted.

* When connecting to a serial port, the `RUN` verb will write string data to the serial device.

* Only `RUN` and `COPY` verbs are supported at this time.

##### FROM

The **FROM** instruction will pull a container image, inspect the layers, and derive all compatible verbs
which are then inserted into the execution process.

##### ENTRYPOINT

The `ENTRYPOINT` verb will create a **simple** systemd service on the target. This will
result in the entrypoint commanded running on system start. All systemd `simple` services
will be placed in `/etc/systemd/system/octahe/`. Where they will be enabled but not started
upon creation.

> To ensure that the generated `ENTRYPOINT` service file is unique, a MD5 SUM of the
  `ENTRYPOINT` value will be generated as the service file name.

##### CMD

This verb is stored in memory and will be used in conjunction with an ENTRYPOINT if defined.

> If multiple CMD verbs are present in config only the last one will be used.

##### HEALTHCHECK

The `HEALTHCHECK` verb will create a watchdog service for a given `ENTRYPOINT` service file.
This will convert the **simple** service to a **notify** service.

The following arguments are supported when a `HEALTHCHECK` is instantiated.

* --interval=30s
* --timeout=30s
* --retries=3

``` dockerfile
HEALTHCHECK --interval=5m --timeout=3s --retries=3 CMD curl -f http://localhost/ || exit 1
```

##### STOPSIGNAL

The `STOPSIGNAL` verb will create a `KillSignal` entry for a given `ENTRYPOINT` systemd.
service.

``` dockerfile
STOPSIGNAL 99
```

##### EXPOSE

The `EXPOSE` verb will create an IPTables rule for a given port and/or service mapping.
IP tables rules will be added into the **INPUT** chain.

``` dockerfile
EXPOSE 80/tcp
EXPOSE 8080:80/udp
```

#### Ignored Verbs

Because the following options have no effect on a stateful targets, they're ignored.

* ONBUILD
* VOLUME

----

### Executing a deployment

The following section covers CLI and output examples.

``` shell
octahe deploy ~/Targetfile
```

``` console
Beginning deployment execution
✔ Step 0/3 : COPY index.html /opt/index.html
✔ Step 1/3 : EXPOSE 7000
✔ Step 2/3 : WORKDIR /opt
✔ Step 3/3 : ENTRYPOINT python3 -m http.server 7000
```

#### Optional Example

By default all targets listed in the `TO` verb will connect and execute the steps serially.
This can be changed by modifying the connection quota. If the quota is less than the total
number of targets, connections will be grouped by the given quota.

``` shell
octahe deploy --connection-quota=3 ~/Targetfile
```

``` console
Beginning deployment execution
✔ Step 0/3 : COPY index.html /opt/index.html
✔ Step 1/3 : EXPOSE 7000
✔ Step 2/3 : WORKDIR /opt
✔ Step 3/3 : ENTRYPOINT python3 -m http.server 7000
```

#### Failure Example

In the event of an execution failure, the failed targets will be taken out of the execution steps.

``` shell
octahe deploy ~/Targetfile
```

``` console
Beginning deployment execution
✔ Step 0/3 : COPY index.html /opt/index.html
⚠ Step 1/3 : EXPOSE 7000
⚠ Step 2/3 : WORKDIR /opt
⚠ Step 3/3 : ENTRYPOINT python3 -m http.server 7000
[-] centos@10.0.0.2:22 - failed step 1 / 2
failedExecution(message: "FAILED: iptables -A INPUT -p tcp -m tcp --dport 7000 -j ACCEPT")
```

#### Manual target Example

To rerun a failed execution on only the failed targets specify the targets on the CLI using the
`--targets` flag.

``` shell
octahe deploy --connection-quota=3 --targets="--name node1 root@10.0.0.4:22" --targets="--via node1 root@10.0.0.6:22" --targets="root@10.0.0.8:22" ~/Targetfile
```

``` console
Beginning deployment execution
✔ Step 0/3 : COPY index.html /opt/index.html
✔ Step 1/3 : EXPOSE 7000
✔ Step 2/3 : WORKDIR /opt
✔ Step 3/3 : ENTRYPOINT python3 -m http.server 7000
```

#### Multi-file Example

A deployment can be executed with more than one file allowing multiple files to be concatenated together.
Each file provided will have the contents of the file inserted into the deployment.

``` shell
octahe deploy ~/Containerfile ~/Targetfile
```

``` console
Beginning deployment execution
✔ Step 0/3 : COPY index.html /opt/index.html
✔ Step 1/3 : EXPOSE 7000
✔ Step 2/3 : WORKDIR /opt
✔ Step 3/3 : ENTRYPOINT python3 -m http.server 7000
```
