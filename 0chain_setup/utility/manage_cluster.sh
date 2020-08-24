#!/bin/bash

export PATH=$PATH:/root/bin
source ~/.profile

validate_port() {
  if [[ $1 -lt 10 ]]; then
    echo "0$1"
  else
    echo $1
  fi
}

bounce_pods() {
  local namespace=$2
  local service=$1
  echo $service
  namespace=${namespace:-$cluster}
  pod_list=$(kubectl get pods -o custom-columns='NAME:metadata.name' --namespace ${namespace} --kubeconfig ${kubeconfig} | grep $service)
  # echo -e "Namespace $namespace \n Service $1 \n List of pods $pod_list"
  if [[ ! -z "$pod_list" ]]; then
    readarray -t pod_list_arr <<<$pod_list
    for pod_name in "${pod_list_arr[@]}"; do
      kubectl delete pods $pod_name --namespace $namespace --kubeconfig ${kubeconfig}
      # echo "Deleting pods ** $i **"
    done
  else
    echo "No such service..."
  fi
}

get_nodes() {
  num_nodes=$(kubectl get nodes --kubeconfig ${kubeconfig} | grep "Ready" | awk '{print $1}' | wc -l)
  echo $num_nodes
}

expand_disk() {
  local service=$1
  local ns=$2
  local svc_to_restart=""
  OIFS=$IFS
  IFS="-"
  serviceArr=($service)
  # for ((i = 0; i < ${#serviceArr[@]}; ++i)); do
  #   echo "serviceArr $i: ${serviceArr[$i]}"
  # done
  search_string=""
  case ${serviceArr[0]} in
  Miner | miner | mine)
    search_string="mine"
    svc_to_restart="miner"
    ;;
  Blobber | blobber | blob)
    search_string="blob"
    svc_to_restart="blobber"
    ;;
  Sharder | sharder | shard)
    search_string="shard"
    svc_to_restart="sharder"
    ;;
  *)
    echo -n "unknown Service"
    exit
    ;;
  esac
  if [[ ${serviceArr[2]} == "data" ]]; then
    search_string="$search_string.*-data"
  elif [[ ${serviceArr[2]} == "log" ]]; then
    search_string="$search_string.*-log"
  fi
  sid=$((${serviceArr[1]}))
  service_id=$(validate_port $sid)
  search_string="$search_string.*-$service_id"
  svc_to_restart="$svc_to_restart-$service_id"
  # echo "$search_string"
  IFS=$OIFS
  pvc_list=$(kubectl get pvc -o custom-columns='NAME:metadata.name' --namespace $ns --kubeconfig ${kubeconfig} | grep -E "$search_string")
  if [[ ! -z "$pvc_list" ]]; then
    readarray -t pvc_list_arr <<<$pvc_list
    for pvc_name in "${pvc_list_arr[@]}"; do
      kubectl patch pvc $pvc_name -p '{"spec": {"resources": {"requests": {"storage": "'${disk_size}'Gi"}}}}' --namespace ${namespace} --kubeconfig ${kubeconfig}
    done
  else
    echo "No such service..."
  fi
  bounce_pods $svc_to_restart $ns
}

set_operation() {
  namespace=${namespace:-$cluster}
  case "$1" in
  bounce-pods)
    bounce_pods $svc_name $namespace
    ;;
  get-nodes)
    get_nodes
    ;;
  expand-disk)
    if [ -z $disk_size ]; then
      echo "No disk size specified exiting..." && exit
    fi
    expand_disk $svc_name $namespace
    ;;
  esac
}

while [ -n "$1" ]; do # while loop starts
  case "$1" in
  --kubeconfig-path)
    kubeconfig="$2"
    shift
    ;;
  --cluster-name)
    cluster="$2"
    shift
    ;;
  --service-name)
    svc_name="$2"
    shift
    ;;
  --disk-size)
    disk_size="$2"
    shift
    ;;
  --namespace)
    namespace="$2"
    shift
    ;;
  --operation)
    set_operation $2
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
# echo $svc_name $cluster $namespace
# ./utility/manage_cluster.sh --kubeconfig-path ../Develop/kubeconfig_oci --cluster-name tech02  --operation get-nodes
# ./utility/manage_cluster.sh --kubeconfig-path ../Develop/kubeconfig_oci --cluster-name tech02  --service-name miner --operation bounce-pods
# ./utility/manage_cluster.sh --kubeconfig-path ../Develop/kubeconfig_oci --cluster-name tech02  --service-name miner-1-data --disk-size 20 --operation expand-disk
