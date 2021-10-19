#!/bin/sh

# Set our config, and load it
cp ./rabia-table-1.config ./config
. ./config

# Our common functions
. ./rabia-common.sh

# Set up
if ! ./setup.sh 'rabia-setup.sh'; then exit 1; fi

# Paper says typical RTT is 0.25ms, so add 0.1ms on all ends, the remaining is the usual latency on a Docker network (empirically checked)
add_latency '0.1'

IP_1="$(get_ip 1)" # Rabia controller, Rabia server, (E)Paxos master
IP_2="$(get_ip 2)" # Rabia server, (E)Paxos replica
IP_3="$(get_ip 3)" # Rabia server, (E)Paxos replica
IP_4="$(get_ip 4)" # Rabia client, (E)Paxos client

printf 'Rabia... '
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'ServerIps=' "ServerIps=($IP_1 $IP_2 $IP_3)"
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'ClientIps=' "ClientIps=($IP_4)"
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'Controller=' "Controller=$IP_1:8070"
use_rabia_profile 'profile_sosp_table1'
run_rabia
get_rabia_results

config_paxos_np()
{
  replace_line '/root/go/src/epaxos-single/runMasterServer.sh' 'MASTER_SERVER_IP=' "MASTER_SERVER_IP=\"$IP_1\""
  replace_line '/root/go/src/epaxos-single/runServer.sh' 'MASTER_SERVER_IP=' "MASTER_SERVER_IP=\"$IP_1\""
  replace_line_on 2 '/root/go/src/epaxos-single/runServer.sh' 'REPLICA_SERVER_IP=' "REPLICA_SERVER_IP=\"$IP_2\""
  replace_line_on 3 '/root/go/src/epaxos-single/runServer.sh' 'REPLICA_SERVER_IP=' "REPLICA_SERVER_IP=\"$IP_3\""
  replace_line '/root/go/src/epaxos-single/runClient.sh' 'MASTER_SERVER_IP=' "MASTER_SERVER_IP=\"$IP_1\""
  # the scripts run stuff in the background by default, let's make them not to
  exec_all 'echo "wait" >> "/root/go/src/epaxos-single/runMasterServer.sh"'
  exec_all 'echo "wait" >> "/root/go/src/epaxos-single/runServer.sh"'
  exec_all 'echo "wait" >> "/root/go/src/epaxos-single/runClient.sh"'
}
exec_paxos_np()
{
  exec_on_silent 1 'cd ~/go/src/epaxos-single ; . runMasterServer.sh' &
  exec_on_silent 2 'cd ~/go/src/epaxos-single ; . runServer.sh' &
  exec_on_silent 3 'cd ~/go/src/epaxos-single ; . runServer.sh' &
  sleep 10 # make sure all servers are connected
  exec_on_silent 4 'cd ~/go/src/epaxos-single ; . runClient.sh > run.txt'
  # wait til the client has exited
  while exec_on 4 'ps aux | grep "bin/client" | grep -v grep' >/dev/null 2>&1 ; do
    sleep 5
  done
  exec_all 'cd ~/go/src/epaxos-single ; . kill.sh'
  wait
}
get_paxos_np_results()
{
  exec_on 4 'cd ~/go/src/epaxos-single ; . calculate_throughput_latency.sh'
}

printf 'Paxos NP... '
exec_all 'cd ~/go/src/epaxos-single ; git checkout paxos-no-pipelining-no-batching ; . compilePaxos.sh'
config_paxos_np
exec_paxos_np
get_paxos_np_results

printf 'EPaxos NP... '
exec_all 'cd ~/go/src/epaxos-single ; git checkout -f epaxos-no-pipelining-no-batching ; . compileEPaxos.sh'
config_paxos_np
exec_paxos_np
get_paxos_np_results


config_paxos()
{
  replace_line '/root/go/src/epaxos/base-profile.sh' 'ServerIps=' "ServerIps=($IP_1 $IP_2 $IP_3)"
  replace_line '/root/go/src/epaxos/base-profile.sh' 'ClientIps=' "ClientIps=($IP_4)"
  replace_line '/root/go/src/epaxos/base-profile.sh' 'MasterIp=' "MasterIp=$IP_1"
}

printf 'Paxos... '
exec_all 'cd ~/go/src/epaxos ; git checkout paxos-no-batching ; . compile.sh'
config_paxos
exec_on_silent 1 'cd ~/go/src/epaxos ; . runPaxos.sh'
kill_paxos
get_paxos_results

printf 'EPaxos... '
exec_all 'cd ~/go/src/epaxos ; git checkout -f epaxos-no-batching ; . compile.sh'
config_paxos
exec_on_silent 1 'cd ~/go/src/epaxos ; . runEPaxos.sh'
kill_paxos
get_paxos_results


./teardown.sh
