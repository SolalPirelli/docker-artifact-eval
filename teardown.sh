#!/bin/sh
# Tears down the containers.
# $1: Optionally, 'all' to also tear down the base image

if [ $# -ne 0 ] && [ "$1" != 'all' ]; then
  echo 'Argument 1 must be either not given or "all".' >&2
  exit 1
fi

. ./config

for i in $(seq 1 $CONFIG_CONTAINER_COUNT); do
  sudo docker rm -f "$CONFIG_CONTAINER_PREFIX$i" >/dev/null 2>&1 &
  rm -f "$CONFIG_CONTAINER_PREFIX$i.log"
done
wait

if [ "$1" = 'all' ]; then
  sudo docker rmi "$CONFIG_CONTAINER_BASE" >/dev/null 2>&1
  sudo docker rm "$CONFIG_CONTAINER_PREFIX$CONFIG_CONTAINER_BASE" >/dev/null 2>&1
  rm -f "$CONFIG_CONTAINER_PREFIX$CONFIG_CONTAINER_BASE.log"
fi
