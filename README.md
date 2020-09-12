
# 0chain Setup in Kubernetes

## Guide to setup the standalone kubernetes cluster


### Set up the 0chain componets in k8s:

Clone the kubernetes repository and change the directory to 0chain_setup and run the below script to setup the 0chain components.

```bash
cd 0chain_setup

bash 0chain-setup.sh
```
Setup script can take input in 3, each of which have a seperatec command format described below.

```
bash
-JSON file
  bash 0chain-setup.sh --input-file ./utility/config/oci_input_premium.json
-Command line arguments # (Argument should appear in same order)
   bash 0chain-setup.sh --cargs test 2 3 6 true true test ../oci-eks/generated/kubeconfig 300 oci oci A 0chainkube latest 3
                                  clustername sharder-count miner-count blobber-count deploy-main deploy-auxiliary host-address kubeconfig-path n2n-delay storage-class cloud-provider dns-record-type registry-image image-tag ceph-instance-count(optional)
-Interactive input
  bash 0chain-setup.sh --input-cli
```
#### Create a config file like input.json inside 0chain_setup


*For standalone deployment (microk8s)*
```
#=============================
{
  "cloud_provider":"on-premise"
  "cluster_name": "test", // Namespace in which all your resources will be created
  "sharder_count": "1",
  "miner_count": "0",
  "blobber_count": "0",
  "deploy_main": true, (optional)
  "deploy_auxiliary": true, (optional)
  "host_address": "test", // Host url for your public IP 
  "kubeconfig_path": "", // path to your kubeconfig, keep it empty to use system configured kubeconfig
  "n2n_delay": 50,  // Delay between node to slow down block creation
  "fs_type": "microk8s-hostpath", // valid file system type (On-premise) [standard/ microk8s-hostpath/ openebs-cstore-sc]
  "repo_type": "0chaintest",  // Repository to use 0chainkube or 0chaintest
  "image_tag": "v1.0.15" // 0chain image version to be used 
  "record_type": "A", (optional) // Dns record type supported by cloud provider (AWS) [CNAME] || (OCI) [A]
  "deployment_type": "PRIVATE", // Use of deployment "PUBLIC" or "PRIVATE"
  "on_premise": { // (optional) only for local kubernetes deployment
    "environment": "microk8s", // Kubernetes environment to bes used (Minikube) "minikube" || (Microk8s) "microk8s"
    "host_ip": "216.218.228.197" //  In case of microk8s provide your local/external IP 
  },
  "standalone": {
    "public_key": "", // Your wallet public key, keep it empty if you want to generate a wallet
    "private_key": "", // Your wallet private key, keep it empty if you want to generate a wallet
    "network": "three", // public Network you like to connect to one or three
    "blobber_delegate_ID": "1d63fc2335bd8d9dcae3ce814299233083647cfd1d8e9a4ab3a4d06f2f99699b", // (blobber only) provide your blobber staking ID
    "read_price": "0.1", // (blobber only) read price for you blobber
    "write_price": "0.1", // (blobber only) write price for you blobber
    "capacity": "1073741824" // (blobber only) capacity for you blobber
  }
}

######### Avaliable capacity #########
#  500 MB - 536870912
#    1 GB - 1073741824
#    2 GB - 2147483648
#    3 GB - 3221225472
#  100 GB - 107374182400
#########  ################ #########
#=============================
```
Few things to be noted:
>By default the script will use the ~/.kube/config path. If our kubconfig file is not at the default location then we need to mention the complete path of our kubeconfig.

Expected results:

* Once, script is executed with required parameters, it will create the corresponding 0chain components (Sharder, Miner, Blobber, Validator, 0proxy, explorer, worker, recorder) in the kubernetes cluster. 
* This will bring up all the required 0chain components in the kubernetes environment.

Once the script is completed then check the pods using the kubectl command
```bash
kubectl get pods -n <cluster_name>
```
If the pods are running/completed(jobs will be shown as completed) then check the URL from the browser and make sure the 0chain blockchain is running.

To get host IP use following kubectl command
```bash
HOST_ADDRESS=$(kubectl get -n ingress-nginx service ingress-nginx-controller -o 'go-template={{range .status.loadBalancer.ingress}}{{print .ip "\n"}}{{end}}')
```
The retrieved url could be use as our `HOST_ADDRESS`. 

> If deployed on a cloud provider like AWS/OCI, we get a public URL as mentioned below depending on our network, as our `HOST_ADDRESS`.
```bash
# {hostname}.{hostnetwork}.net
- {hostname}.testnet-0chain.net
- {hostname}.devnet-0chain.net
- {hostname}.0chain.com
# Incase of OCI premium deployment because we are using 2 loadbalancers we get a seperate url along with above URL
- blobbers.{hostname}.testnet-0chain.net
```
List of all miners and sharders could be directly retrieved from following block-worker URL

```bash
Worker:
  http://{hostname}.{hostnetwork}-0chain.net/dns/
  # URL for miner & sharder list & magic-block details
  http://{hostname}.{hostnetwork}-0chain.net/dns/network
  ##example http://three.testnet-0chain.net/dns/network
For A basic deployment our initial miners, sharders and blobbers list will look like
miners:
- http://{HOST_ADDRESS}:31201
- http://{HOST_ADDRESS}:31202
- http://{HOST_ADDRESS}:31203

sharders:
- http://{HOST_ADDRESS}:31101
- http://{HOST_ADDRESS}:31102

blobbers:
- http://{HOST_ADDRESS}:31301
- http://{HOST_ADDRESS}:31302
- http://{HOST_ADDRESS}:31303
- http://{HOST_ADDRESS}:31304
- http://{HOST_ADDRESS}:31305
- http://{HOST_ADDRESS}:31306

explorer:
- http://{HOST_ADDRESS}

0proxy:
- http://{HOST_ADDRESS}/proxy/
```

