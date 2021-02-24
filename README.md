
## Guide to setup the 0miner on kubernetes cluster

## Requirements

- Platform : ubuntu 18.04
- 4 vCPU, 8 Gb Memory (minimum)


## Step 1. Install and setup MicroK8s on Linux
```bash
sudo snap install microk8s --classic --channel=1.17/stable
sudo snap start microk8s
```
#### Check the status while Kubernetes starts
```bash
sudo microk8s status --wait-ready
export PATH=$PATH:/snap/bin
```
### Setup required tools

- Jq
 ```bash
sudo apt update && sudo apt install jq -y
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
sudo apt update && sudo apt install python3-pip -y
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
Note: If running on EC2, provide public ip range when asked for enabling metallb e.g. 3.134.116.182-3.134.116.182 if public ip of your instance is 3.134.116.182

Note: Microk8s setup does not include dns pointing. You have to make dns entries in etc/hosts file or Route53 to access it.

#### (Optional) Create a .env file in 0chain_setup directory if you want to enable minio tiering for sharders and blobbers. 
*Enter values inside quotes accordingly*
```
ACCESS_KEY_ID=""
SECRET_ACCESS_KEY=""
BUCKET_URL=""
BUCKET_REGION=""
SHARDER_BUCKET_NAME=""
BLOBBER_BUCKET_NAME=""
```
*Enable minio in 0chain_setup/Sharders_tmplt/Configmap/configmap-zchain-yaml-config.yaml*

*Enable minio in 0chain_setup/Blobbers_tmplt/Configmap/configmap-blobber-config.template*

#### Edit 0chain_setup/utility/config/on-prem_input_microk8s_standalone.json and provide correct values for host_ip, < your-domain >, network_url, etc.

#### At last execute the setup script using
```bash
bash 0chain-standalone-setup.sh --input-file utility/config/on-prem_input_microk8s_standalone.json
```
#### Sample input file
```

{
  "cloud_provider": "on-premise",
  "cluster_name": "test", // Namespace in which all your resources will be created
  "sharder_count": "1", // number of sharder you want to deploy 
  "miner_count": "1", // number of miner you want to deploy 
  "blobber_count": "1", // number of blobber you want to deploy 
  "deploy_main": true, 
  "deploy_auxiliary": true,
  "host_address": "<your-domain>", // Host url for your public IP 
  "host_ip": "18.217.219.7", // Host ip 
  "kubeconfig_path": "", // path to your kubeconfig, keep it empty to use system configured kubeconfig
  "n2n_delay": "", // Delay between node to slow down block creation
  "fs_type": "microk8s-hostpath", // valid file system type (On-premise) [standard/ microk8s-hostpath/ openebs-cstore-sc]
  "repo_type": "0chaintest", // Repository to use 0chainkube or 0chaintest
  "image_tag": "latest", // image version to be used 
  "record_type": "A", // Dns record type supported by cloud provider (AWS) [CNAME] || (OCI) [A]
  "deployment_type": "public", // Use of deployment "PUBLIC" or "PRIVATE"
  "monitoring": {
    "elk": "true", // always true 
    "elk_address": "elastic.<your-domain>", // leave empty if you want to access elk on nodeport
    "rancher": "true",
    "rancher_address": "rancher.<your-domain>",
    "grafana": "true",
    "grafana_address": "grafana.<your-domain>" // leave empty if you want to access grafana on nodeport
  },
  "on_premise": {
    "environment": "microk8s", 
    "host_ip": "18.217.219.7" // Host ip
  },
  "standalone": {
    "public_key": "",
    "private_key": "",
    "network_url": "two.devnet-0chain.net", // url of the network you want to join
    "blobber_delegate_ID": "20bd2e8feece9243c98d311f06c354f81a41b3e1df815f009817975a087e4894",
    "read_price": "",
    "write_price": "",
    "capacity": ""
  }
}

```

#### Verify and validate the deployment

To verify and validate the deployment visit `https://<network_url>/sharder01/_diagnostics`

#### Check logs and metrices.

When the script is executed, you can check logs and metrices by visiting kibana and grafana urls given as output by the script. Below is an example of how kibana and grafana look after the deployment.

<img src="https://github.com/0chain/0miner/blob/https_changes/images/kibana.png" width="400" />         <img src="https://github.com/0chain/0miner/blob/https_changes/images/grafana.png" width="400" />  

#### Manage Deployment.

To manage pods you can use rancher deployed on rancher.<your-domain> 
 
<img src="https://github.com/0chain/0miner/blob/https_changes/images/rancher.png" width="400" />  

#### Reset

To reset network for fresh deployment use:

```bash
bash 0chain-standalone-setup.sh --input-file utility/config/on-prem_input_microk8s_standalone.json --reset true
```

