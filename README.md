<p align="center">
<img src="assets/octahe_logo.png" alt="Octahe" title="Octahe" />
</p>

[![License](https://img.shields.io/badge/license-GPL-blue.svg)](https://github.com/peznauts/swift-octahe/blob/master/LICENSE)
[![Twitter](https://img.shields.io/twitter/follow/Peznaut.svg?style=social)](https://twitter.com/intent/follow?screen_name=peznaut)

# Octahe

## Evolve your application by devolving the stack. 

Octahe allows you to simplfy operations, create concies applications, and focus on what you do best.

### Test in containers, Deploy `TO` production.


This application is being created to better enable teams to deploy application into more robust
targets, without the constraints of a container. Given the proliferation of containers it is safe
to assume most of the core logic that enables the worlds applications resides within
**Containerfile**(s). While containers are generally fantastic tools, they can be limiting, they
can create application complexities, and they do create bottlenecks. octahe aims to enable teams to
deploy applications into stateful targets, with **Containerfile**(s), without any of the
containerization machinery.

#### Configuration

The Octahe follows the [Dockerfile](https://docs.docker.com/engine/reference/builder)
reference with one new verb, `TO`. This new verb can be expressed on the CLI or within
a provided container file.

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
