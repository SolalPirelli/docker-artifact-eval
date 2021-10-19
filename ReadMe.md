# Docker for artifact eval example

This is an example of using this repo for an artifact, in this case Rabia for SOSP'21.

Rabia was originally intended to run on some cloud VMs, but these scripts retrofit it to run in a Docker container instead,
including faking network latency to mimic different VM layouts across regions.

The entry point is `rabia.sh`.
