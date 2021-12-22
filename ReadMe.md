# Docker for artifact eval

This repo contains helper scripts to run an artifact on multiple "machines", but using Docker containers instead of machines,
making it easy to test an artifact without having to own multiple machines or pay for VMs on a cloud provider.

Edit `./config` with the values the artifact needs, such as packages.

Call `./setup.sh` first to set up the containers, optionally passing a custom setup script to e.g. clone the artifact's repository.
Then, load `./config` and use its helper functions as necessary.
Finally, run `./teardown.sh` to tear down the containers.

The first time `./setup.sh` is run, it will take a while as it needs to create a Docker image for the artifact.
Future runs are quick as it only needs to create containers from that image.

See the `rabia` branch for an example: retrofitting the Rabia artifact from SOSP'21.

## Docker basics

[Docker](https://www.docker.com/) allows you to package your artifact in a _container_, which runs using the same kernel as your host machine,
unlike virtual machines which include an entire operating system.

It's a good way to package artifacts because it allows anyone to use the artifact without having to install dependencies on their own machine.
From the authors' point of view, providing a Docker container also saves time debugging issues on other people's machines.

Docker is easier to use than virtual machines because it is lightweight, provides a built-in way to interact with the container without having to install tools in the guest,
and because it forces the authors to write a "Dockerfile" containing the exact commands necessary to install the artifact,
which also serves as documentation for anyone wanting to install the artifact on their own machine.

You should consider providing a Docker container for your artifact unless it has no dependencies beyond common ones such as Python, or it has complex hardware dependencies that are hard to use
within a Docker container.

### Writing a Dockerfile

Create a file named `Dockerfile`. While there are [many commands available](https://docs.docker.com/engine/reference/builder/), the main ones are:
- `FROM <image>` selects the base image
- `RUN <command>` runs a command
- `ENV <key>=<value>` sets an environment variable
- `COPY <src> <dst>` copies a local file into the container
- `# ...` denotes comments
- `\` can be used within commands to break lines

Here is an example:

```
FROM ubuntu:20.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y git build-essential

# Install the artifact, add some configuration, and build it
RUN git clone https://example.com/artifact
COPY artifact.config /artifact/artifact.config
RUN make -C artifact

# Add the artifact to the PATH
ENV PATH=/artifact/bin:$PATH

# Remove apt-get's cache to minimize the container image's size
RUN rm -rf /var/lib/apt/lists/*
```

From the directory containing this `Dockerfile` (and the `artifact.config` file used in the `COPY` command),
one can run `docker build -t artifact .` to create an image with the name `artifact`,
then `docker run -it artifact` to run a container using this image in an `i`nteractive way with a `t`erminal.
You may need to run these commands with `sudo`, if you have not [given Docker privileges to your user](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user).


### Simulating networks

You can create multiple Docker containers to simulate a set of machines running on the same network, and even add network delays.

Docker lets you [configure complex networks](https://docs.docker.com/network/) if you need to,
but you can use the default network without additional configuration.

To add delays, first pass `--cap-add=NET_ADMIN` to `docker run`, then use `tc` within the container from the Ubuntu `iproute2` package,
for instance `tc qdisc add dev eth0 root netem delay 5ms` to add a 5ms delay to the `eth0` interface.

Use the `--cpuset-cpus` parameter of `docker run` to pin containers to cores, avoiding interference between containers.


### Dockerfile tips

All commands within a Dockerfile must be non-interactive. This means, for instance, passing `-y` to `apt-get` so it will not ask for confirmation.

By default, a Docker Ubuntu image only contains the `root` user, and uses the root path `/` as its working directory.
You can change the working directory with Docker's [`WORKDIR` command](https://docs.docker.com/engine/reference/builder/#workdir),
and you may need to install the `sudo` package if your artifact uses it, allowing scripts to work both within and outside of Docker.
You could also [create and use a non-root user](https://docs.docker.com/engine/reference/builder/#user), though this is not necessary.

OS images within Docker are typically more bare-bones than their client counterparts, so you may need more dependencies than you think
because some dependencies that came built-in your OS are not installed by default in the equivalent OS in Docker.

Some Debian/Ubuntu packages prompt the user for input during installation, notably `tzdata` asking for the user's geographical location.
This will cause installation to fail within Docker.
To avoid this, prepend `DEBIAN_FRONTEND=noninteractive` to your `apt-get install` commands.

You can grant Linux capabilities to a container when running it using [`--cap-add`](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities),
or even root privileges using `--privileged`.
This allows you to package artifacts that require root privileges to run, at the cost of losing Docker's runtime isolation benefits.
