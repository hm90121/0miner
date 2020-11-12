
## Guide to setup the 0miner on kubernetes cluster

## Step 1. Install and setup MicroK8s on Linux
```bash
sudo snap install microk8s --classic --channel=1.17/stable
```
#### Check the status while Kubernetes starts
```bash
microk8s status --wait-ready
export PATH=$PATH:/snap/bin
```
### Setup required tools

- Jq
 ```bash
sudo apt update && sudo apt install jq
```
- Kubectl
 ```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl 

chmod +x ./kubectl 
sudo mv ./kubectl /usr/local/bin/kubectl 
kubectl version --client
```

- python3 & pip3  
```bash
sudo apt update && sudo apt install python3-pip
pip3 install -U PyYAML
```

- Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

### Fetch microk8s kubeconfig to access it using kubectl
```bash
sudo su
mkdir ~/.kube
microk8s config > ~/.kube/config
kubectl get po -A
```

## Step 2. Set up the 0chain componets in k8s:

Clone the kubernetes repository and change the directory to 0chain_setup and run the below commands to setup the 0chain components. There are some predefined configs as well in utility/config/ directory make the changes in them if you don't want to create the new json from scratch.

```bash
git clone https://github.com/0chain/0miner.git
cd 0miner/0chain_setup
bash utility/local_k8s.sh 
pip3 install -r utility/requirements.txt
```
Provide the required inputs after that and you are all done for the microk8s part. 

Note: Microk8s setup does not include dns pointing. You have to make dns entries in etc/hosts file or Route53 to access it.

#### At last execute the setup script using
```bash
bash 0chain-standalone-setup.sh --input-file utility/config/on-prem_input_microk8s_standalone.json
```



Reset command:
```bash
bash 0chain-standalone-setup.sh --input-file utility/config/on-prem_input_microk8s_standalone.json --reset true
```

