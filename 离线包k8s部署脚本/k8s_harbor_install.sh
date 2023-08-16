#!/bin/bash

# 配置免密钥
ALL_SERVER_ROOT_PASSWORD=000000
all_hosts=`cat /etc/hosts |awk '{print $1}' |sed '/::1/d'|sort -u`
all_hostname=`cat /etc/hosts |awk '{print $2}' |sort -u`
a_hosts="$all_hosts  $all_hostname"
my_ip=`ip a |grep -w "inet" |awk '{print $2}'|sed 's/\/.*//g'`
other_ip=$all_hosts
for i in $my_ip;do other_ip=`echo $other_ip |sed "s/$i//g"`;done

yum install -y expect
if [[ ! -s ~/.ssh/id_rsa.pub ]];then
    ssh-keygen  -t rsa -N '' -f ~/.ssh/id_rsa -q -b 2048
fi
for hosts in $a_hosts; do
    ping $hosts -c 4 >> /dev/null 2>&1
    if [ 0  -ne  $? ]; then
        echo -e "\033[31mWarning\n$hosts IP unreachable!\033[0m"
    fi
    expect -c "set timeout -1;
    spawn ssh-copy-id  -i /root/.ssh/id_rsa  $hosts ;
    expect {
        *(yes/no)* {send -- yes\r;exp_continue;}
        *assword:* {send -- $ALL_SERVER_ROOT_PASSWORD\r;exp_continue;}
        eof        {exit 0;}
    }";
done


# 配置 时间同步
IP=`ip addr | grep 'state UP' -A2 | grep inet | egrep -v '(127.0.0.1|inet6|docker)' | awk '{print $2}' | tr -d "addr:" | head -n 1 | cut -d / -f1`
yum install -y chrony
sed -i '3,6s/^/#/g' /etc/chrony.conf
sed -i "7s|^|server $IP iburst|g" /etc/chrony.conf
echo "allow all" >> /etc/chrony.conf
echo "local stratum 10" >> /etc/chrony.conf
systemctl restart chronyd
systemctl enable chronyd
timedatectl set-ntp true
sleep 5
systemctl restart chronyd
chronyc sources

# 关闭swap分区
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab

# 修改 /etc/sysctl.conf
modprobe br_netfilter
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
sysctl -p

# 安装 Docker-ce
yum install -y yum-utils device-mapper-persistent-data lvm2
yum install -y docker-ce
systemctl enable docker
systemctl start docker

# 修改 Docker Cgroup Driver为systemd
tee /etc/docker/daemon.json <<-'EOF'
{
  "insecure-registries" : ["0.0.0.0/0"],
"registry-mirrors": ["https://5twf62k1.mirror.aliyuncs.com"], 
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl restart docker

# 安装docker-compose
chmod +x /opt/docker-compose/v1.25.5-docker-compose-Linux-x86_64 
mv /opt/docker-compose/v1.25.5-docker-compose-Linux-x86_64 /usr/local/bin/docker-compose 

# 导入镜像
for i in $(ls /opt/images|grep tar)
do
  docker load -i /opt/images/$i
done

# 安装Harbor仓库
IP=`ip addr | grep 'state UP' -A2 | grep inet | egrep -v '(127.0.0.1|inet6|docker)' | awk '{print $2}' | tr -d "addr:" | head -n 1 | cut -d / -f1`
cd /opt/harbor/
tar -zxvf harbor-offline-installer-v2.1.0.tgz
cd harbor
mv harbor.yml.tmpl harbor.yml
sed -i "5s/reg.mydomain.com/${IP}/g" harbor.yml
sed -i "13s/^/#/g" harbor.yml
sed -i "15,18s/^/#/g" harbor.yml
./prepare || exit
./install.sh --with-clair || exit
docker-compose ps
echo "请在浏览器通过http://${IP}访问Harbor"

