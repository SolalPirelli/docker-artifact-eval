#!/bin/sh

# This script also implements the "vd" experiment, because it's almost the same code, but by default it does figure 4

if [ $# -eq 0 ]; then
  echo 'Running 4a and 4b...'
  "./$0" ab
  echo ''
  echo 'Running 4c...'
  "./$0" c
  echo ''
  echo 'Running 4d...'
  "./$0" d
  exit 0
fi

if [ "$1" != 'ab' ] && [ "$1" != 'c' ] && [ "$1" != 'd' ] && [ "$1" != 'vd' ]; then
  echo "Call with 'ab', 'c', or 'd'."
  exit 1
fi

# Set our config, and load it
if [ "$1" = 'd' ]; then
  cp ./rabia-figure-4d.config ./config
else
  cp ./rabia-figure-4abc.config ./config
fi
. ./config

# Our common functions
. ./rabia-common.sh

# Set up
if ! ./setup.sh 'rabia-setup.sh'; then exit 1; fi

if [ "$1" = 'c' ]; then
  # 3 regions, clients in the same region as replica 1, 0.4ms average latency across zones with 0.17ms variance
  # we can't easily emulate the variance since the containers have a single interface, so just put some wildly different variances,
  # that should replicate the intent
  add_latency_on 1 0.05
  add_latency_on 2 0.5
  add_latency_on 3 0.7
  add_latency_on 4 0.05
  add_latency_on 5 0.05
  add_latency_on 6 0.05
else
  # Paper says RTT is 0.25ms, single region, so 0.1ms both ways everywhere
  add_latency '0.1'
fi

IP_1="$(get_ip 1)" # paxos master
if [ "$1" = 'd' ]; then
  SERVER_IPS="$IP_1 $(get_ip 2) $(get_ip 3) $(get_ip 4) $(get_ip 5)"
  CLIENT_IPS="$(get_ip 6) $(get_ip 7) $(get_ip 8)"
else
  SERVER_IPS="$IP_1 $(get_ip 2) $(get_ip 3)"
  CLIENT_IPS="$(get_ip 4) $(get_ip 5) $(get_ip 6)"
fi

echo 'Rabia...'
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'ServerIps=' "ServerIps=($SERVER_IPS)"
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'ClientIps=' "ClientIps=($CLIENT_IPS)"
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'Controller=' "Controller=$IP_1:8070"
RABIA_PROFILE='profile_sosp_4abc'
if [ "$1" = 'd' ]; then
  RABIA_PROFILE='profile_sosp_4d'
elif [ "$1" = 'vd' ]; then
  RABIA_PROFILE='profile_sosp_vd' # note: uses "modulo" for clients so "cps" below is unused, apparently intentional
fi
use_rabia_profile "$RABIA_PROFILE"
if [ "$1" = 'vd' ]; then
  clear_rabia
  replace_line '/root/go/src/rabia/internal/config/config.go' 'c.KeyLen =' 'c.KeyLen = 128'
  replace_line '/root/go/src/rabia/internal/config/config.go' 'c.ValLen =' 'c.ValLen = 128'
fi
for numclients in 20 40 60 80 100 200 300 400 500 ; do
  cps=''
  if [ "$1" = 'd' ]; then
    cps='20 0 0 0 0'
    if [ $numclients -eq 40 ] ; then cps='20 20 0 0 0' ; fi
    if [ $numclients -eq 60 ] ; then cps='20 20 20 0 0' ; fi
    if [ $numclients -eq 80 ] ; then cps='20 20 20 20 0' ; fi
    if [ $numclients -eq 100 ] ; then cps='20 20 20 20 20' ; fi
    if [ $numclients -eq 200 ] ; then cps='40 40 40 40 40' ; fi
    if [ $numclients -eq 300 ] ; then cps='60 60 60 60 60' ; fi
    if [ $numclients -eq 400 ] ; then cps='80 80 80 80 80' ; fi
    if [ $numclients -eq 500 ] ; then cps='100 100 100 100 100' ; fi
  else
    cps='20 0 0'
    if [ $numclients -eq 40 ] ; then cps='20 20 0' ; fi
    if [ $numclients -eq 60 ] ; then cps='20 20 20' ; fi
    if [ $numclients -eq 80 ] ; then cps='40 20 20' ; fi
    if [ $numclients -eq 100 ] ; then cps='40 40 20' ; fi
    if [ $numclients -eq 200 ] ; then cps='80 60 60' ; fi
    if [ $numclients -eq 300 ] ; then cps='100 100 100' ; fi
    if [ $numclients -eq 400 ] ; then cps='140 140 120' ; fi
    if [ $numclients -eq 500 ] ; then cps='180 160 160' ; fi
  fi
  replace_line "/root/go/src/rabia/deployment/profile/$RABIA_PROFILE.sh" 'NClients=' "NClients=$numclients"
  replace_line "/root/go/src/rabia/deployment/profile/$RABIA_PROFILE.sh" 'Rabia_ClientsPerServer=' "Rabia_ClientsPerServer=($cps)"
  run_rabia
  echo "$numclients clients: $(get_rabia_results)"
  clear_rabia
done


config_paxos()
{
  replace_line '/root/go/src/epaxos/base-profile.sh' 'ServerIps=' "ServerIps=($SERVER_IPS)"
  replace_line '/root/go/src/epaxos/base-profile.sh' 'ClientIps=' "ClientIps=($CLIENT_IPS)"
  replace_line '/root/go/src/epaxos/base-profile.sh' 'MasterIp=' "MasterIp=$IP_1"
  if [ "$1" = 'd' ]; then
    replace_line '/root/go/src/epaxos/base-profile.sh' 'NumOfServerInstances=' 'NumOfServerInstances=5'
  fi
}

echo 'Running Paxos...'
if [ "$1" = 'vd' ]; then
  exec_all 'cd ~/go/src/epaxos ; git checkout paxos-batching-data-size-256B'
else
  exec_all 'cd ~/go/src/epaxos ; git checkout paxos-batching'
fi
# the compile.sh script depends on GOPATH but it's not set properly :/ so we compile stuff ourselves
exec_all 'cd ~/go/src/epaxos ; GOPATH=~/go/src/epaxos/ go install master ; GOPATH=~/go/src/epaxos/ go install server ; GOPATH=~/go/src/epaxos/ go install client'
config_paxos "$1"
for prof in 0 1 2 3 4 5 6 7 8; do
  replace_line '/root/go/src/epaxos/runPaxos.sh' 'source .\/profile' "source ./profile$prof.sh"
  exec_on_silent 1 'cd ~/go/src/epaxos ; . runPaxos.sh'
  echo "profile $prof: $(get_paxos_results)"
  kill_paxos
  exec_on_silent 1 'cd ~/go/src/epaxos ; rm -rf ./logs'
done

# almost the same, but with "EPaxos.sh" as a script name; also, no GOPATH fix needed here
echo 'Running EPaxos...'
if [ "$1" = 'vd' ]; then
  exec_all 'cd ~/go/src/epaxos ; git checkout -f epaxos-batching-data-size-256B'
  # this branch has a bug, it sources a non-existent file
  replace_line '/root/go/src/epaxos/runEPaxos.sh' 'base-profile0.sh' 'source ./base-profile.sh'
else
  exec_all 'cd ~/go/src/epaxos ; git checkout -f epaxos-batching'
fi
exec_all 'cd ~/go/src/epaxos ; . compile.sh'
config_paxos "$1"
for prof in 0 1 2 3 4 5 6 7 8; do
  replace_line '/root/go/src/epaxos/runEPaxos.sh' 'source .\/profile' "source ./profile$prof.sh"
  exec_on_silent 1 'cd ~/go/src/epaxos ; . runEPaxos.sh'
  echo "profile $prof: $(get_paxos_results)"
  kill_paxos
  exec_on_silent 1 'cd ~/go/src/epaxos ; rm -rf ./logs'
done

./teardown.sh
