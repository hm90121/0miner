# On-premise kubeadm Getting Started with the kubernetes cluster Guide

## Steps to setup the kubernetes cluster With on premise bash script

Clone the latest code from github kubernetes repository in the master branch

```bash
git clone https://github.com/0chain/kubernetes.git

cd kubernetes/on-premise

```
Create a input.json config file like this
```
{
  "masters": {
    "ansible_host": "38.32.112.211", // master host public ip
    "ansible_user": "ubuntu" // username for ssh login 
  },
  "workers": [ // In case of a single machine cluster or no worker use empty array -> []
    { 
      "name": "worker1",
      "ansible_host": "38.32.112.222", // worker1 host public ip
      "ansible_user": "ubuntu" // username for ssh login 
    },
    { 
      "name": "worker2",
      "ansible_host": "38.32.112.333",  // worker2 host public ip
      "ansible_user": "ubuntu" // username for ssh login 
    }
  ]
}
```

Run the setup.sh script as a root/sudo user

```bash
bash oci-setup.sh
```

This will install and configure the following packages in the local and remote servers,

In local Server:
- Install python3-pip
- Install the kubectl command to manage the kubernetes components
- Install ansible

On Remote Server:
- Create a ubuntu user with root privileage and no password prompt
- Install docker
- Install kubernetes tools like kubdeadm, kubectl, kubelet, etc...
- Run kubeinit command to initialize the cluster and create kube config
- Install fanal and deploy overlay network
- Connect worker node with master node
- Install open-ebs for volume management

Check and make sure the nodes are ready using the below command from the deployment machine once the script is completed successfully.
Ssh into master node and execute the following command

```bash

kubectl get nodes
```

This will show the node list added to the control plane and its status similar to the showing below.

```bash

====================================
NAME      STATUS    ROLES     AGE       VERSION
master    Ready     master    1d        v1.14.0
worker1   Ready     <none>    1d        v1.14.0
worker2   Ready     <none>    1d        v1.14.0
====================================
```
Make sure nodes are ready.
