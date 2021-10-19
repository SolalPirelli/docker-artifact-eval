use_rabia_profile()
{
  replace_line '/root/go/src/rabia/deployment/run/multiple.sh' 'run_once$' 'run_once ${RCFolder}/deployment/profile/'"$1.sh"
}
run_rabia()
{
  # Rabia assumes $USER is defined but in a container it's not
  replace_line '/root/go/src/rabia/deployment/profile/profile0.sh' 'User=' 'User=root'
  exec_on_silent 1 'cd ~/go/src/rabia/deployment/run ; . multiple.sh'
}
get_rabia_results()
{
  exec_on 1 'cat ~/go/src/rabia/result.txt' | head -n 2 | tail -n 1 | tr -d ',' | awk '{print "Tput " $1 ", Lat50 " $16 ", Lat99 " $18}'
}
clear_rabia()
{
  exec_on_silent 1 'cd ~/go/src/rabia/deployment/run ; . clear.sh'
}

kill_paxos()
{
  exec_all 'cd ~/go/src/epaxos ; . kill.sh'
}
get_paxos_results()
{
  exec_on 1 'cd ~/go/src/epaxos ; python3.8 analysis.py ./logs' |  tail -n 1 | sed 's/.*clientp50Latency: \([0-9\.]*\).*clientp99Latency: \([0-9\.]*\).*throughput: \([0-9\.]*\).*/Tput: \3, Lat50: \1, Lat99: \2/'
}
