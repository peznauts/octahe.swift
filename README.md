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

### Building Octahe From Source.

Octahe requires libssh2 be installed on the system prior to building. `libssh2` can be installed
using `brew` using the following commands.

``` shell
brew install libssh2
```

With swift 5.2+ installed, simply clone this repository, change directory to the checkout, and run
the following command.

``` shell
swift build
```

Once complete, the application will be built, and available in the default build location,
`.build/debug/octahe`. 

## Usage

The CLI interactions are familiar and simple.

``` shell
octahe deploy ~/Targetfile
```

This is what you can expect from the process output.

``` console
Beginning deployment execution
Probing targets
Step 0/2 : COPY index.html /
 --> Done
Step 1/2 : EXPOSE 7000
 --> Done
Step 2/2 : ENTRYPOINT python3 -m http.server 7000
 --> Done
```

More documentation can be found [here](DOCUMENTATION.md)
