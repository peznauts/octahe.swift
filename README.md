<p align="center">
<img src="assets/octahe_logo.png" alt="Octahe" title="Octahe" />
</p>

[![License](https://img.shields.io/badge/license-GPL-blue.svg)](https://github.com/peznauts/swift-octahe/blob/master/LICENSE)
[![Twitter](https://img.shields.io/twitter/follow/Peznaut.svg?style=social)](https://twitter.com/intent/follow?screen_name=peznaut)

# (O)ctahe

Octahe allows you to simplify operations, create concise applications, and focus on what you do best.

## Evolve your application by devolving the stack.

Whether you're deploying software to the cloud, building high-performance computing
environments, or IOT applications, Octahe has it covered. The Zero footprint design,
employed by Octahe will get you up and running in as little as one step.

### Test in containers, Deploy `TO` production.

While containers are fantastic tools, they can be limiting, they can create application
complexities, and they do create bottlenecks. Octahe aims to enable teams to deploy
applications into stateful Targets, using the simplicity of **Containerfile**(s),
without any of the machinery that comes alone with containers.

#### Configuration

The Octahe follows the [Dockerfile](https://docs.docker.com/engine/reference/builder)
reference with one new verb, [TO](DOCUMENTATION.md#to). This new verb can be expressed
on the CLI or within a provided container file.

#### Target options

When deploying [TO](DOCUMENTATION.md#to) a target Octahe provides options by supporting
options that span SSH, `localhost`, and Serial.

## Installation

Building Octahe is simple, however, if you already have swift-lang installed on your
system, you can simply skip this part and download one of the prebuild binaries from
the [releases](https://github.com/peznauts/octahe.swift/releases).

### Building Octahe

#### Octahe dependencies on OSX 10.15

Octahe requires libssh2 be installed on the system prior to building. `libssh2` can be installed
using `brew` using the following commands.

``` shell
brew install libssh2
```

#### Octahe dependencies on CentOS 8

Install `EPEL`.

``` shell
dnf -y install epel-release libssh2-devel openssl-devel
```

Install `swift-lang`.

``` shell
dnf -y install swift-lang libssh2-devel openssl-devel
```

#### Building the Octahe binary

With swift 5.2+ installed, simply clone this repository, change directory to the checkout,
and run the following command.

``` shell
swift build \
      --configuration release \
      --jobs 4 \
      -Xswiftc \
      -g
```

Once complete, the application will be built, and available in the release build location,
`.build/release/octahe`. To make Octahe available system wide, copy it into a `${PATH}`
directory, useually something like `/usr/local/bin`.

### Deploying Octahe in Containers

Octahe can also be deployed using container native tooling, such as `podman` or `docker`.

``` shell
podman build -t octahe.master -f Containerfile
```

Once the container image has been created, you can build applications around Octahe or run
commands through the default container image runtime.

``` shell
podman run -it localhost/octahe.master octahe
```

### Octahe deploying Octahe

Because Octahe can read Containerfiles and deploy applications to targets, Octahe can be used
to deploy itself using the provided in tree `Containerfile`. Assuming Octahe is installed on
the local machine the following command can be used to deploy the application to remote hosts.

``` shell
octahe -k ~/.ssh/id_rsa Containerfile -t ${USER}@${SERVER}:22 -k ~/.ssh/id_rsa
```

## Usage

The CLI interactions are familiar and simple.

``` shell
octahe -k ~/.ssh/id_rsa ~/Targetfile
```

The console output is simple, and easy to follow.

``` console
Beginning deployment execution
✔ Step 0/3 : COPY index.html /opt/index.html
✔ Step 1/3 : EXPOSE 7000
✔ Step 2/3 : WORKDIR /opt
✔ Step 3/3 : ENTRYPOINT python3 -m http.server 7000
```

Here's the application being deployed to 5 remote [T](DOCUMENTATION.md#to)argets in realtime.

![octahe-run](assets/octahe-run.gif)

----

More documentation and examples can be found [here](DOCUMENTATION.md).
