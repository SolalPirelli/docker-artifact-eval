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
