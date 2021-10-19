#!/bin/sh
# Sets up the containers.
# $1: Extra setup script to run (optional)

# Load config
if [ ! -f './config' ]; then
  echo 'ERROR: ./config file not found' >&2
  exit 1
fi
. ./config

# Check we have the dependencies we need
check_dep()
{
  if [ -z "$(which $1)" ]; then
    echo "ERROR: '$1' not found, please install it." >&2
    exit 2
  fi
}
check_dep 'bc'
check_dep 'docker'
check_dep 'ssh-keygen'

if [ "$(echo "$CONFIG_CONTAINER_COUNT * $CONFIG_CONTAINER_CPUS" | bc)" -gt "$(nproc)" ]; then
  echo 'ERROR: Not enough CPU cores given the desired number of containers and cores per container'
  exit 3
fi

echo 'Setting up all nodes...' >&2

# Create the base container only if needed
if ! sudo docker inspect "$CONFIG_CONTAINER_BASE" >/dev/null 2>&1; then
  echo 'Base image not found, creating it...' >&2

  sudo docker run --detach --tty \
                  --name "$CONFIG_CONTAINER_PREFIX$CONFIG_CONTAINER_BASE" \
                  "$CONFIG_OS_IMAGE" \
                  > "$CONFIG_CONTAINER_PREFIX$CONFIG_CONTAINER_BASE.log"

  # Disable 'mesg' on startup because it just prints an error since we don't run it with a tty
  exec_on_silent "$CONFIG_CONTAINER_BASE" 'sed -i "/mesg n/d" ~/.profile'

  # We need packages, so run this once and for all
  exec_on_silent "$CONFIG_CONTAINER_BASE" "$CONFIG_OS_PACKAGE_UPDATE"

  # Install the packages we need and any necessary extra packages
  exec_on_silent "$CONFIG_CONTAINER_BASE" "$CONFIG_OS_PACKAGE_INSTALL $CONFIG_OS_IP_PACKAGE $CONFIG_OS_TC_PACKAGE $CONFIG_CONTAINER_PACKAGES"

  # Install SSH if needed, ensuring it does not prompt to accept hosts
  if [ "$CONFIG_CONTAINER_SSH" = 'yes' ]; then
    exec_on_silent "$CONFIG_CONTAINER_BASE" 'mkdir -p /root/.ssh'
    exec_on_silent "$CONFIG_CONTAINER_BASE" "$CONFIG_OS_PACKAGE_INSTALL $CONFIG_OS_SSHD_PACKAGE ; printf 'Host *\n    StrictHostKeyChecking no\n' > /root/.ssh/config"
  fi

  # Execute the custom script if needed
  if [ $# -eq 1 ] ; then
    exec_on_file "$CONFIG_CONTAINER_BASE" "$1"
  fi

  # Commit this container as a template
  sudo docker commit "$CONFIG_CONTAINER_PREFIX$CONFIG_CONTAINER_BASE" "$CONFIG_CONTAINER_BASE"

  # Stop it, we don't need it any more
  sudo docker stop "$CONFIG_CONTAINER_PREFIX$CONFIG_CONTAINER_BASE"
fi

# Create containers
for i in $(seq 1 $CONFIG_CONTAINER_COUNT); do
  # Set the NET_ADMIN capability so 'tc' can be used to add latency
  sudo docker run --cpuset-cpus "$(echo "($i-1) * $CONFIG_CONTAINER_CPUS" | bc)-$(echo "$i * $CONFIG_CONTAINER_CPUS - 1" | bc)" \
                  --detach --tty \
                  --name "$CONFIG_CONTAINER_PREFIX$i" \
                  --cap-add=NET_ADMIN \
                  "$CONFIG_CONTAINER_BASE" \
                  > "$CONFIG_CONTAINER_PREFIX$i.log" &
done
wait

# Set up SSH keys if needed, same key for all containers
if [ "$CONFIG_CONTAINER_SSH" = 'yes' ]; then
  # in case some old ones are still there, e.g. after a failed run
  rm -f sshkey
  rm -f sshkey.pub
  ssh-keygen -b 2048 -t rsa -f sshkey -q -N ''
  copy_all 'sshkey' '/root/.ssh/id_rsa'
  copy_all 'sshkey.pub' '/root/.ssh/id_rsa.pub'
  exec_all 'cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys'
  rm sshkey
  rm sshkey.pub
fi

# Start SSH
exec_all "$CONFIG_OS_SSHD_START"
