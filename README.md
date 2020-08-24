# 0chain Setup in Kubernetes

## Guide to setup the kubernetes cluster
  <!-- To setup the kubernetes cluster follow [this](#steps-to-setup-the-kubernetes-cluster) -->
  Please refer to following
  - [Amazon cloud (AWS)](https://github.com/0chain/kubernetes/blob/managed_kubernetes/aws-eks/README.md)
  - [Oracle cloud (OCI)](https://github.com/0chain/kubernetes/blob/managed_kubernetes/oci-eks/README.md)
  - [Local/Personal (Minikube/Microk8s)](https://github.com/0chain/kubernetes/blob/managed_kubernetes/on-premise/README.md)

## Set up the 0chain componets in k8s:

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
*For general purpose cloud based deployment*
```
## Value in double quotes and square braces must be used
#=============================
{
  "cloud_provider": (AWS) "aws" || (OCI) "oci", || (Minikube/Microk8s) "on-premise"
  "cluster_name": "test-deployment", // Namespace in which all your resources will be created
  "sharder_count": "3", // Number of sharders to be deployed
  "miner_count": "3", // Number of miners to be deployed
  "blobber_count": "3", // Number of blobbers and validators to be deployed
  "deploy_main": true, // If you want to deploy miner, sharders, worker and blobbbers only
  "deploy_auxiliary": true, // If you want to deploy recorder, 0proxy, explorer only
  "host_address": "test", // Host url with which you will access 0chain deployment. It will generate url like "test.devnet-0chain.net" 
  "kubeconfig_path": "", // path to your kubeconfig, leave it empty to use default system configured kubectl
  "n2n_delay": 100, // Delay between node to slow down block creation
  "fs_type": "gp2", // valid file system type (AWS) "gp2" || (OCI) "oci" || (On-premise) [standard/ microk8s-hostpath/ openebs-cstore-sc]
  "repo_type": "0chainkube", // Repository to use 0chainkube or 0chaintest
  "image_tag": "latest" // 0chain image version to be used 
  "record_type": "A", // Dns record type supported by cloud provider (AWS) [CNAME] || (OCI) [A]
  "deployment_type": "PRIVATE", // Use of deployment "PUBLIC" or "PRIVATE"
  "on_premise": { // (optional) only for local kubernetes deployment
    "environment": "microk8s", // Kubernetes environment to bes used (Minikube) "minikube" || (Microk8s) "microk8s"
    "host_ip": "216.218.228.197" //  In case of microk8s provide your local/external IP & for minikube provide minikube ip i.e. $(minikube ip)
  },
  "deploy_svc": { // (optional) If you want to omit some service while deployment just set those services to false like explorer and recorder here. To deploy all services omit the deploy_svc block.
    "miner": true,
    "sharder": true,
    "blobber": true,
    "worker": true,
    "explorer": false,
    "recorder": false,
    "zbox": false,
    "zproxy": true
  }
}
#=============================
```

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
// for aws
HOST_ADDRESS=$(kubectl get -n ambassador service ambassador -o 'go-template={{range .status.loadBalancer.ingress}}{{print .hostname "\n"}}{{end}}')
// for oci
HOST_ADDRESS=$(kubectl get -n ambassador service ambassador -o 'go-template={{range .status.loadBalancer.ingress}}{{print .ip "\n"}}{{end}}')
echo $HOST_ADDRESS
```
It will provide you url like 'aa5a200c649bf11ea93ac06feb395c1e-763194721.us-east-2.elb.amazonaws.com' for `AWS` & like '129.146.145.130' for `OCI`, The retrieved url could be use as our `HOST_ADDRESS`. 

> If deployed on a cloud provider like AWS/OCI, we get a public URL as mentioned below depending on our network, as our `HOST_ADDRESS`.
```bash
# {hostname}.{hostnetwork}.net
- {hostname}.testnet-0chain.net
- {hostname}.devnet-0chain.net
- {hostname}.0chain.com
# Incase of OCI premium deployment because we are using 2 loadbalancers we get a seperate url along with above URL
- blobbers.{hostname}.testnet-0chain.net
```
List of all miners and sharders could be deirectly retrieved from following block-worker URL

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

## Instruction to use disk expansion script:
#### For disk-expansion on cloud use manage_cluster script in utility folder, below command can be used for disk-expansion
```bash
./utility/manage_cluster.sh --kubeconfig-path ../Develop/kubeconfig_oci --cluster-name test01  --service-name miner-1-data --disk-size 20 --operation expand-disk
```
Currently disk expansion is avaliable only for miner, sharder and blobber service. Disk size must be specified in GigaBytes. Service name must follow the definite structure. For example, if we want to expands data volume for miner01 we will specify "miner-1-data".
> (service_name)-(deployment_count)-(volume_type)
// Volume type could be data or log

#### For on-prem HA cluster disk-expansion for
- ssh into node on which disk is attached
- Make sure openebs is installed on kubernetes node with the help of
```
kubectl get storageclass
// expected output
##################################################
NAME                        PROVISIONER                                                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
nfs                         cluster.local/nfs-server-provisioner                       Delete          Immediate              true                   6d4h
openebs-cstore-sc           openebs.io/provisioner-iscsi                               Delete          Immediate              false                  6d4h
openebs-device              openebs.io/local                                           Delete          WaitForFirstConsumer   false                  6d4h
openebs-hostpath            openebs.io/local                                           Delete          WaitForFirstConsumer   false                  6d4h
openebs-jiva-default        openebs.io/provisioner-iscsi                               Delete          Immediate              false                  6d4h
openebs-snapshot-promoter   volumesnapshot.external-storage.k8s.io/snapshot-promoter   Delete          Immediate              false                  6d4h
##################################################
```
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
> Latest changes are present in 0chain_setup/on-prem/disk-expansion folder