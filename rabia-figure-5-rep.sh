#!/bin/sh

if [ $# -eq 0 ]; then
  echo 'Running (1)...'
  "./$0" 1
  echo ''
  echo 'Running (2)...'
  "./$0" 2
  exit 0
fi

if [ "$1" != '1' ] && [ "$1" != '2' ]; then
  echo "Call with '1' or '2'."
  exit 1
fi

# Set our config, and load it
if [ "$1" = '1' ]; then
  cp ./rabia-figure-5-rep-1.config ./config
else
  cp ./rabia-figure-5-rep-2.config ./config
fi
. ./config

# Our common functions
. ./rabia-common.sh

# Set up
if ! ./setup.sh 'rabia-setup.sh'; then exit 1; fi

# Paper says RTT is 0.25ms, single region, so 0.1ms both ways everywhere
add_latency '0.1'

IP_1="$(get_ip 1)" # master
IP_2="$(get_ip 2)" # follower 1
if [ "$1" = '2' ]; then
  IP_3="$(get_ip 3)" # follower 2
fi

replace_line '/root/go/src/redis-sync-rep/config.yaml' 'MasterIp:' "MasterIp: $IP_1"

# sleep to make sure everyone has a chance to start properly
exec_on_silent 1 'cd ~/go/src/redis-sync-rep ; . ./deployment/startRedis/startServer.sh'
sleep 10
exec_on_silent 2 'cd ~/go/src/redis-sync-rep ; . ./deployment/startRedis/startServer.sh replica'
sleep 10
if [ "$1" = '2' ]; then
  exec_on_silent 3 'cd ~/go/src/redis-sync-rep ; . ./deployment/startRedis/startServer.sh replica'
  sleep 10
fi

run_redis()
{
  exec_on 2 'cd ~/go/src/redis-sync-rep ; go run main.go' 2>/dev/null | head -n 1 | sed 's/.*Throughput:\([0-9\.]*\).*P50Lat:\([0-9\.]*\).*P99Lat:\([0-9\.]*\).*/Tput: \1, Lat50: \2, Lat99: \3/'
}

printf 'Low bar... '
replace_line '/root/go/src/redis-sync-rep/config.yaml' 'NClients:' 'NClients: 1'
replace_line '/root/go/src/redis-sync-rep/config.yaml' 'ClientBatchSize:' 'ClientBatchSize: 1'
run_redis

printf 'High bar... '
replace_line '/root/go/src/redis-sync-rep/config.yaml' 'NClients:' 'NClients: 15'
replace_line '/root/go/src/redis-sync-rep/config.yaml' 'ClientBatchSize:' 'ClientBatchSize: 20'
run_redis

./teardown.sh
