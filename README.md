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

## Install

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
Step 0/4 : FROM image-name:tag-id
 ---> done
Step 1/4 : ARG USER=access-user
 ---> done
Step 2/4 : TO [("10.0.0.1:22@root")]
 ---> done
Step 3/4 : RUN dnf update && dnf add install && rm -r /var/cache/  # Inserted into deployment FROM inspected image,
 ---> done
Step 4/4 : ENTRYPOINT 0a25e5f88885e1564daab76f1bbcc8ffc38b9d29 created
 ---> done
Successfully deployed.
```

More documentation can be found [here](DOCUMENTATION.md)
