# Getting Started with the 0chain minikube/microK8s On-premise deployment Guide

Clone the latest code from github kubernetes repository in the managed_kubernetes branch

```bash
git clone https://github.com/0chain/kubernetes.git
Git checkout managed_kubernetes
cd kubernetes
```
## Setup requirement tools
Requirements for 0chain deployment script
- bash
- jq
- curl
- kubectl
- envsubst (get-text on mac)
- python3 & pip3
>Install python requiements with pip3 install -r requirements.txt
## Setting up haproxy as an external load balancer
To enable url host for on-prem cluster it require us to use a system based Load balancer that can redirect request from port 80 to nginx port. 
- First get nginx port using following command
```bash
-> kubectl get svc -n ingress-nginx ingress-nginx-controller
-> ingress-nginx-controller   LoadBalancer   10.233.23.142   <pending>     31101:31101/TCP,31102:31102/TCP,31103:31103/TCP,31201:31201/TCP,31202:31202/TCP,31203:31203/TCP,31204:31204/TCP,31205:31205/TCP,31206:31206/TCP,31301:31301/TCP,31302:31302/TCP,31303:31303/TCP,31304:31304/TCP,31305:31305/TCP,31306:31306/TCP,31307:31307/TCP,31308:31308/TCP,31309:31309/TCP,31310:31310/TCP,31311:31311/TCP,31312:31312/TCP,80:32687/TCP,443:30921/TCP   2d

-> kubectl get pods -n ingress-nginx  -o wide
-> NAME                                        READY   STATUS      RESTARTS   AGE    IP              NODE    NOMINATED NODE   READINESS GATES
ingress-nginx-admission-create-zb7ss        0/1     Completed   0          2d1h   10.233.67.2     node4   <none>           <none>
ingress-nginx-admission-patch-zmnr6         0/1     Completed   0          2d1h   10.233.69.169   node5   <none>           <none>
ingress-nginx-controller-84bd7c74bc-x2pl8   1/1     Running     0          2d1h   10.233.67.4     node4   <none>           <none>

```
You will get output like above, Identify kubernetes port assocaited with port 80. In this case it is 32687 save it somewhere we will need it later. Then identify the ip of node on which ingress-nginx-controller pod is running, in above case it is node6
 
- Then Install haproxy on your node to act as a system level loadbalancer with below command
```bash
-> sudo apt install -y haproxy
```
- Setup haproxy config file
```bash
-> sudo nano /etc/haproxy/haproxy.cfg 
# Add following snippet to end of config file
listen two (Network name)
    bind 0.0.0.0:80
    mode tcp
    timeout connect  4000
    timeout client   180000
    timeout server   180000
    server srv1 38.32.112.211:32687 (NodeIP:NodePort)

>If you are using docker vmdriver then 4gb rams is enough but with virtual machine VM-driver like kvm2 or virutalbox try to have atleast 6Gb RAM reserved for minikube.


## Common steps or deployment
### Setup entry in in your system hosts file

- mac `/etc/hosts`
- ubuntu `/etc/hosts`
- windows `c:\Windows\System32\Drivers\etc\hosts`
> Windows users need to have bash and jq installed on their system in order to use the deployment script

Follow this guide for more information: [Host Guide](https://www.webhostface.com/kb/knowledgebase/modify-hosts-file/#:~:text=Modifying%20the%20hosts%20file%20under%20MAC%20OS,navigate%20and%20edit%20the%20file.)

1. Get your local minikube ip on which minikube will expose its services with following command
```
Replace nodeIP and nodeport as identified in previous step.
- Restart HA-proxy service & get its status.
```bash
-> sudo systemctl restart haproxy
-> sudo systemctl status haproxy
```
- Change the node number in 0chain_setup/function.sh to  node on which we want to create deployment
```python
  python3 ../update_label.py k8s-yamls/deployment-${n}-${file} 1 '4' #(node number for deployment)
```

## How to use disk expansion script
- ssh into node on which disk is attached
- Use following command to see current disk states
```bash
kubectl -n openebs get csp
kubectl -n openebs get spc
kubectl -n openebs get bd
kubectl -n openebs get bdc
```

- cd to ~/disk-expansion folder on each nodes home directory
- execute the below disk expansion command
```
./expand_openebs_disk.sh  --disk-path /dev/sdb      --disk-type ssd
                         (Path of the disk to add) (Disk type to add [ssd/hdd])
```
Latest changes are present in 0chain_setup/on-prem/disk-expansion folder
