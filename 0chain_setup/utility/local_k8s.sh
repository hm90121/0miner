#!/usr/bin/env bash
read -p "Provide your external/host IP: " host_ip
echo "This may take some time, please wait..."
microk8s stop
microk8s start
microk8s enable ingress cilium dns storage metallb
microk8s enable host-access:ip=${host_ip}
echo "Enabled micr0k8s on your system"
exit
