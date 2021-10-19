mkdir -p ~/go/src

git clone https://github.com/haochenpan/rabia.git ~/go/src/rabia
cd ~/go/src/rabia/deployment
# The script appends to ~/.bashrc, but that file abandons unless $PS1 is set meaning the shell is interactive,
# and trying to pretend a Docker shell is interactive runs into all kinds of issues; plus, it's a bash-only thing
# Use .profile instead, and just tell the shell it's a login shell to make it source .profile
sed -i 's/.bashrc/.profile/g' ./install/install.sh
. ./install/install.sh

git clone https://github.com/zhouaea/epaxos-single.git ~/go/src/epaxos-single

git clone https://github.com/zhouaea/epaxos.git ~/go/src/epaxos

git clone https://github.com/yichengshen/redis-sync-rep.git ~/go/src/redis-sync-rep
