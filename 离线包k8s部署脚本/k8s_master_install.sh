#!/bin/bash

# 安装 Kubeadm
yum install -y kubelet-1.18.1 kubeadm-1.18.1 kubectl-1.18.1

systemctl enable kubelet
systemctl start kubelet
docker -v
kubelet --version

# 初始化 master 节点
IP=`ip addr | grep 'state UP' -A2 | grep inet | egrep -v '(127.0.0.1|inet6|docker)' | awk '{print $2}' | tr -d "addr:" | head -n 1 | cut -d / -f1`
kubeadm init --kubernetes-version=1.18.1 --apiserver-advertise-address=$IP --image-repository $IP/library --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sleep 50
kubectl get pod -n kube-system -owide

# 部署 flannel网络
sed -i "s/quay.io\/coreos/$IP\/library/g" /opt/yaml/flannel/kube-flannel.yaml
kubectl apply -f /opt/yaml/flannel/kube-flannel.yaml
sleep 30

# 部署dashboard
mkdir dashboard-certs
cd dashboard-certs/
kubectl create namespace kubernetes-dashboard
openssl genrsa -out dashboard.key 2048
openssl req -days 36000 -new -out dashboard.csr -key dashboard.key -subj '/CN=dashboard-cert'
openssl x509 -req -in dashboard.csr -signkey dashboard.key -out dashboard.crt
kubectl create secret generic kubernetes-dashboard-certs --from-file=dashboard.key --from-file=dashboard.crt -n kubernetes-dashboard
sed -i "s/kubernetesui/$IP\/library/g" /opt/yaml/dashboard/recommended.yaml 
kubectl apply -f /opt/yaml/dashboard/recommended.yaml 
kubectl apply -f /opt/yaml/dashboard/dashboard-adminuser.yaml

# 删除污点
kubectl taint nodes master node-role.kubernetes.io/master-


# 登录信息
token=`kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep dashboard-admin | awk '{print $1}')`
echo ""
echo ""
echo ""
echo "dashboard地址：https://$IP:30000"
echo "登录令牌：$token"

