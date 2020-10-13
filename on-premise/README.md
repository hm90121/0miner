
# Getting Started with the 0chain minikube/microK8s On-premise deployment Guide

Clone the latest code from github kubernetes repository in the managed_kubernetes branch

```bash
git clone https://github.com/0chain/0miner.git
sudo su 
cd 0miner
```
## Setup requirement tools
Requirements for 0chain deployment script
- bash
- jq - `sudo apt update && sudo apt install jq`
- curl
- kubectl 
```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl && kubectl version --client 
```
- envsubst (get-text on mac)
-  Install python3-pip
`
 sudo apt update && sudo apt upgrade && sudo apt install python3-pip
 pip3 install -U PyYAML
`
>Install python requiements with pip3 install -r requirements.txt
## Setup kubernetes environment
### Install any of the below local kubernetes providers
- [Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
- [Microk8s](https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s#2-deploying-microk8s)

### Setup local  kubernetes providers
For `automatic setup` we can use local_k8s script in utility folder
```bash
cd 0chain_setup/utility
bash ./local_k8s.sh 
# Just provide your operating system and environment by answering the prompts after execution
# Script will automatically setup environment for you
// In case of minikube  
bash ./local_k8s.sh {memory} {disk-size}
# example: bash ./local_k8s.sh 4096 50g
```
### For manual setup refer to below guide.

**Setup Microk8s on your local machine.**

Enable following microk8s addons before moving to deployment
> host_ip is the IP you want to expose your microk8s cluster on, the same host_ip entry will be made in our etc/hosts file for mac and linux
- cilium
- dns
- storage
- metallb
`microk8s enable metallb {host_ip}-{host_ip} -> 172.17.0.3-172.17.0.3`
- host-access
`microk8s enable host-access:ip={host_ip}`

**Setup Minikube on your local machine.**

Enable following minikube addons before moving to deployment
- metallb
- ingress-dns
- storage (If not enabled)
>Enable metallb with minikube addons enable metallb #Make sure you are using latest version
### Setup your minikube vm driver.
Currently following vm-driver has been tested based on opertaing system.
Operating System | Virtual machine driver
------------ | -------------
Linux | KVM (prefered) & Docker
Windows | Hyperv(prefered) & Virtualbox
Mac | Hyperkit

### Run your minikube instance with following command

```bash
# Create minikube cluster
minikube start --memory=4096 --disk-size=50g --driver={os-vm-driver} --enable-default-cni --network-plugin=cni
# Enable metallb if not done previously
minikube addons enable metallb  
# Install cilium cni so that service can communicate with each other
kubectl create -f https://raw.githubusercontent.com/cilium/cilium/1.7.5/install/kubernetes/quick-install.yaml
```
Note:
* If no driver is specified minikube will use default driver present on system.
* If multple driver are present minikube will use its default driver i.e. docker
* Currently docker driver on mac is not compataible with 0chain & use it will led to broken inter-service communication

For a minikube cluster with 4gb ram and 2 vcpus, limit the deployment size to 2 miners, 2 sharders & 2 blobbers. If container get stuck at container cerating trying reducing pvc size for all services. You can also try increasing vm size or disabling some of the services like recorder & worker, In case you are only interested in working blockchain.

>If you are using docker vmdriver then 4gb rams is enough but with virtual machine VM-driver like kvm2 or virutalbox try to have atleast 6Gb RAM reserved for minikube.


### `Finally,cloud ` Create a 0chain deployment by following the deployment guide.
