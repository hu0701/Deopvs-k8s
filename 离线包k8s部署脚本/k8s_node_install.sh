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
MASTER_IP=`cat /etc/hosts | grep master | awk '{print$1}'`
yum install -y chrony
sed -i '3,6s/^/#/g' /etc/chrony.conf
sed -i "7s|^|server $MASTER_IP iburst|g" /etc/chrony.conf
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
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/k8s.conf

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

# 安装Kubeadm
yum install -y kubelet-1.18.1 kubeadm-1.18.1 kubectl-1.18.1
systemctl enable kubelet
systemctl start kubelet
kubelet --version

# 登录Harbor
images_hub() {

    while true;
    do
        read -p "输入镜像仓库地址(不加http/https): " registry
        read -p "输入镜像仓库用户名: " registry_user
        read -p "输入镜像仓库用户密码: " registry_password
        echo "您设置的仓库地址为: ${registry},用户名: ${registry_user},密码: xxx"
        read -p "是否确认(Y/N): " confirm

        if [ $confirm != Y ] && [ $confirm != y ] && [ $confirm == '' ]; then
            echo "输入不能为空，重新输入"
        else
            break
        fi
    done
}

images_hub
docker login -u ${registry_user} -p ${registry_password} ${registry}

#  加入集群
ssh master "kubeadm token create --print-join-command" >token.sh
chmod +x token.sh && source token.sh && rm -rf token.sh
sleep 20
ssh master "kubectl get nodes"
