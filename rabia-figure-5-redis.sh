#!/bin/sh

if [ $# -eq 0 ]; then
  echo 'Low bar...'
  "./$0" a
  echo ''
  echo 'High bar...'
  "./$0" b
  exit 0
fi

if [ "$1" != 'a' ] && [ "$1" != 'b' ]; then
  echo "Call with 'a' or 'b'."
  exit 1
fi


# Set our config, and load it
cp ./rabia-figure-5-redis.config ./config
. ./config

# Our common functions
. ./rabia-common.sh

# Set up
if ! ./setup.sh 'rabia-setup.sh'; then exit 1; fi

# Paper says RTT is 0.25ms, single region, so 0.1ms both ways everywhere
add_latency '0.1'

IP_1="$(get_ip 1)" # server
IP_2="$(get_ip 2)" # server
IP_3="$(get_ip 3)" # server
IP_4="$(get_ip 4)" # client
IP_5="$(get_ip 5)" # client
IP_6="$(get_ip 6)" # client

clear_rabia
replace_line '/root/go/src/rabia/internal/config/config.go' 'c.StorageMode =' 'c.StorageMode = 2'

replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'ServerIps=' "ServerIps=($IP_1 $IP_2 $IP_3)"
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'ClientIps=' "ClientIps=($IP_4 $IP_5 $IP_6)"
replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'Controller=' "Controller=$IP_1:8070"
use_rabia_profile "profile_sosp_5$1"

exec_on_silent 1 '~/redis-6.2.2/src/redis-server --port 6379 --appendonly no --save "" --daemonize yes'
exec_on_silent 2 '~/redis-6.2.2/src/redis-server --port 6380 --appendonly no --save "" --daemonize yes'
exec_on_silent 3 '~/redis-6.2.2/src/redis-server --port 6381 --appendonly no --save "" --daemonize yes'

sleep 10 # make sure redis has started

run_rabia
get_rabia_results

./teardown.sh
