#!/usr/bin/env bash
#set -x
scriptdir="$(dirname "$0")"
cd "$scriptdir"

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

export PATH=$PATH:/root/bin
source ~/.profile

chars="/-\|"
NEWLINE=$'\n'
TAB=$'\t\t\t\t\t'
SPACES8=$"          "
SPACES4=$"     "
TEST_RUN="-o yaml --dry-run=client"
KUBE_EXTRA_ARGS=""
SP=1
EP=$(($SP - 1))
step_count=0
script_index=2
development=false
standalone=true

source ./function.sh

if [ -z "$1" ]; then
  user_input_deployment
fi

while [ -n "$1" ]; do # while loop starts
  case "$1" in
  --input-cli)
    cli_input_deployment
    ;;
  --input-file)
    input_file_path="$2"
    echo -e "Following path for input file is provided $input_file_path"
    user_input_deployment $input_file_path
    echo "Using following json"
    cat $input_file_path
    shift
    ;;
  --reset)
    reset_cluster=true
    reset_only=$2
    ;;
  --development)
    development=true
    ;;
  --cargs)
    cluster=$2
    s=$3
    m=$4
    b=$5
    deploy_main=$6
    deploy_auxiliary=$7
    host_name=$8
    kubeconfig=$9
    n2n_delay=${10}
    fs_type=${11}
    cloud_provider=${12}
    record_type=${13}
    REGISTRY_IMAGE=${14}
    TAG=${15}
    ceph_instance_count=${16}
    dtype=${17}
    shift
    break
    ;;
  --)
    shift # The double dash makes them parameters
    break
    ;;
  *) echo -e "Option $1 not recognized" ;;
  esac
  shift
done

REGISTRY_IMAGE=${REGISTRY_IMAGE:-0chainkube}
TAG=${TAG:-latest}

echo -e "\e[32m Receieved input $cluster $s $m $b $deploy_main $deploy_auxiliary $host_name $kubeconfig $n2n_delay $fs_type $cloud_provider $record_type $REGISTRY_IMAGE $TAG $ceph_instance_count\e[39m"
if [ -z "$cluster" ] || [ -z "$host_name" ]; then
  echo "Invalid data recieved"
  exit 1
fi

if [ ! -d "$PWD/../inventory/mycluster/artifacts" ]; then
  mkdir -p $PWD/../inventory/mycluster/artifacts
  chmod -R 755 $PWD/../inventory/mycluster/artifacts
  mkdir -p $PWD/../inventory/mycluster/logs
  chmod -R 755 $PWD/../inventory/mycluster/logs
fi

# if [ -f "$log_path" ]; then
#   echo "$log_path exist"
#   rm $log_path
# fi

log_path="$PWD/../inventory/mycluster/logs/deploy_logs_$cluster.log"
append_logs "Node pool is ready Initiating deployment"

echo -e "\e[93m =================== Initializing config =================== \e[39m" && append_logs "Initializing required deployment configuration"
kubeconfig=${kubeconfig:-~/.kube/config}
echo -e $kubeconfig
cp $kubeconfig "$PWD/../inventory/mycluster/artifacts/Kubeconfig_$cluster.conf"
kubeconfig="$PWD/../inventory/mycluster/artifacts/Kubeconfig_$cluster.conf"
# count=$(cat $PWD/../inventory/mycluster/artifacts/instance_count.txt)
count=${ceph_instance_count:-3}
kube_context=$(kubectl config current-context --kubeconfig ${kubeconfig})
dtype=${dtype:-"PUBLIC"}
[[ ! -z $dtype && $dtype == "PRIVATE" ]] && config_dir="Configmap_enterprise" || config_dir="Configmap"
echo -e "\e[32m Final Kubeconfig: ${kubeconfig}${NEWLINE} Final context${kube_context}${NEWLINE} Deployment Type: ${dtype}${NEWLINE}\e[39m"
# [[ $development == true ]] && progress_bar 6 || echo "Proceeding with deployment"
# host_address=$host_url

# Reset cluster if required
if [ "$reset_cluster" == true ]; then
  echo -e "\e[31m Resetting cluster for fresh deployment \e[39m"
  cluster_reset $cluster $kubeconfig
  rm $log_path
  progress_bar 180
  if [ "$reset_only" == true ]; then
    exit 1
  else
    progress_bar $reset_only
  fi
fi

# echo  "--------------------------------------------------------------------------------------------------------------------------------------------------------------------"
if [ $cloud_provider != "on-premise" ]; then
  echo -e "\e[93m =================== Adding labels to node =================== \n \e[39m" && append_logs "Configuring nodes for High Availability"
  node_list=$(kubectl get nodes --kubeconfig ${kubeconfig} -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{"\n"}{end}')
  node_count=1
  if [[ $node_count -gt 1 ]]; then
    for i in $node_list; do
      echo -e "node $i assigned label node-$node_count"
      kubectl label nodes $i instance=node-$node_count --overwrite=true --kubeconfig ${kubeconfig}
      ((node_count++))
    done
    ((node_count--))
  fi
  if [ $node_count -le 0 ]; then
    echo -e "\e[31m Nodes not ready yet, exiting... ${NEWLINE} Please restart deployment\e[39m"
    exit 1
  fi
  node_count=$(kubectl get nodes --kubeconfig ${kubeconfig} | grep "Ready" | awk '{print $1}' | wc -l)
else
  node_count=$(kubectl get nodes --kubeconfig ${kubeconfig} | grep "Ready" | awk '{print $1}' | wc -l)
  echo "On-prem deployment detected node count is $node_count"
fi
echo -e "\e[32m Total number of nodes $node_count \e[39m"

echo -e "\e[93m =================== Creating namespace ${cluster} & Adding node delay =================== \e[39m" && append_logs "Creating namespace & Configuring inter node delay"
kubectl create ns $cluster --kubeconfig $kubeconfig $KUBE_EXTRA_ARGS
sleep 3s
kubectl create -f regcred.yaml --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
mkdir -p k8s-yamls && rm -f k8s-yamls/*

if [[ $n2n_delay -gt 0 ]]; then
  add_delay $n2n_delay
else
  cp -f Keygen/n2n_delay_default.txt Keygen/n2n_delay.yaml
fi
progress_bar 6
kubectl create configmap n2n-delay-yaml --kubeconfig ${kubeconfig} --namespace $cluster --from-file=Keygen/n2n_delay.yaml -o yaml $KUBE_EXTRA_ARGS >Keygen/k8s-yamls/n2n-delay.yaml

echo -e "\e[93m =================== Applying cloud specififc config =================== \n \e[39m"
ns_ambassador=$(kubectl get ns --kubeconfig ${kubeconfig} | grep "ambassador" | awk '{print $1}')

if [ $cloud_provider == "on-premise" ]; then
  host_zone_id="/hostedzone/Z3IUIOABG02M88" && domain_name="devnet-0chain.net"
  # remote_ip=$(jq -r .remote_ip $json_source)
  [[ -z $host_ip || $host_ip == null ]] && host_ip=$(minikube ip)
  create_bucket on-premise
  rwm_sc=${fs_type}
  blobber_limit=15 # for oci 6 & aws 15
  data_volume_size=5
  log_volume_size=1
fi
host_address="216.218.228.197"
block_worker_url="http://${network}.devnet-0chain.net/dns"

echo $network

if [[ $m == 1 ]]; then
  config_dir="Sharders_tmplt/Configmap_enterprise"
  for file in $(ls $config_dir); do
    if [[ $file == *.yaml ]]; then
      echo -e "\e[32m Creating kubernetes Configmap ${file}... \e[39m"
      kubectl create -f $config_dir/${file} --kubeconfig $kubeconfig --namespace $cluster
    fi
  done
fi

if [[ $cloud_provider == "on-premise" && ! -z $host_ip ]]; then
  pushd Load_balancer/metallb
  echo -e "\e[32m Patching metalb for external IP ${host_ip}\e[39m"
  host_ip=${host_ip} envsubst <metallb_config.template >metallb_config.yaml
  kubectl apply -f metallb_config.yaml --namespace metallb-system --kubeconfig $kubeconfig
  # kubectl -n ambassador patch svc ambassador --patch "$(cat k8s-yamls/ambassador_svc_eip_patch.yaml)" --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
  popd
fi

configure_standalone_dp
# kubectl create configmap magic-block-config --kubeconfig ${kubeconfig} --namespace $cluster --from-file=on-prem/wallet/magicBlock.json -o yaml $KUBE_EXTRA_ARGS >k8s-yamls/magic_block.yaml
# kubectl create configmap wallet-keys-config --kubeconfig ${kubeconfig} --namespace $cluster --from-file=wallet.txt=on-prem/wallet/wallet_blobber.txt -o yaml $KUBE_EXTRA_ARGS >k8s-yamls/wallet.yaml
# kubectl create configmap owner-keys-config --kubeconfig ${kubeconfig} --namespace $cluster --from-file=b0owner_keys.txt=on-prem/wallet/owner_keys.txt -o yaml $KUBE_EXTRA_ARGS >k8s-yamls/owner.yaml

config_dir="Configmap_enterprise"
pushd Keygen
blobber_delegate_ID=$(./blobber_keygen --keys_file "./k8s-yamls/${cluster}_blob_keys.json")
popd
blobber_delegate_ID=${blobber_delegate_ID} block_worker_url=${block_worker_url} read_price=${read_price} write_price=${write_price} envsubst <Blobbers_tmplt/$config_dir/configmap-blobber-config.template >Blobbers_tmplt/$config_dir/configmap-blobber-config.yaml

if [[ $deploy_main == true ]]; then
  if [[ $s =~ ^[0-9]+$ && $s -gt 0 && $s -le 99 ]]; then
    if [[ $is_deploy_sharder != false ]]; then
      echo -e "\e[93m =================== Creating the Sharder components =================== \e[39m" && append_logs "Creating Sharders"
      k8s_deply Sharders_tmplt $s 8
      for n in $(seq $s); do
        n=$(validate_port $n)
        kubectl wait --for=condition=available deployment/sharder-$n -n ${cluster} --kubeconfig $kubeconfig
      done
      [[ $standalone == true ]] && expose_deployment_lb sharder $s 311
    # progress_bar $((20 * $s))
    else
      echo -e "Skipping sharder service"
    fi
  else
    echo -e 'Please provide the number greater than "0" & less than equal to 99 to create Sharder service'
  fi

  if [[ $m =~ ^[0-9]+$ && $m -gt 0 && $m -le 99 ]]; then
    if [[ $is_deploy_miner != false ]]; then
      echo -e "\e[93m =================== Creating the Miner components =================== \e[39m" && append_logs "Creating Miners"
      k8s_deply Miners_tmplt $m 4
      for n in $(seq $m); do
        n=$(validate_port $n)
        kubectl wait --for=condition=available deployment/miner-$n -n ${cluster} --kubeconfig $kubeconfig
      done
      # progress_bar $((15 * $m))
      [[ $standalone == true ]] && expose_deployment_lb miner $m 312
    else
      echo -e "Skipping miner service"
    fi
  else
    echo -e 'Please provide the number greater than "0" & less than equal to 99 to create Miners service'
  fi

  if [[ $b =~ ^[0-9]+$ && $b -gt 0 && $b -le 99 ]]; then
    if [[ $is_deploy_blobber != false ]]; then
      echo -e "\e[93m =================== Creating the Blobber and Validator components =================== \e[39m" && append_logs "Creating Blobbers"
      k8s_deply Blobbers_tmplt $b 2
      host_address=$(get_host external)
      [[ $standalone == true ]] && expose_deployment_lb blobber $b 313 && exit
      # progress_bar $((10 * $b))
    else
      echo -e "Skipping blobber service"
    fi
  else
    echo -e 'Please provide the number greater than "0" & less than equal to 99 to create Blobbers service'
  fi
fi
# echo  "--------------------------------------------------------------------------------------------------------------------------------------------------------------------"
