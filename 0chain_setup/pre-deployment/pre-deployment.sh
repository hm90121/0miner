#!/bin/bash
export compartment_id="ocid1.tenancy.oc1..aaaaaaaau4uzaar4poyqhwxoh5ielbcs53fu3ttv45s3bv6nkxxsudris5eq"
source ../0chain_setup/function.sh

scriptdir="$(dirname "$0")"
cd "$scriptdir"

scale_kubernetes() {
  replica_count=$1
  local namespace=$2
  echo "Scaling $namespace to $replica_count"
  kubectl get deploy -n $namespace -o name --kubeconfig ${kubeconfig} | xargs -I % kubectl scale % --replicas=$replica_count -n $namespace --kubeconfig ${kubeconfig}
  kubectl get deployments -n $namespace --kubeconfig ${kubeconfig}
}

scale_node_pool() {
  pool_size=$1
  cluster_id=${cluster_id:-$2}
  node_pool_id=$(oci ce node-pool list --compartment-id ${compartment_id} --cluster-id ${cluster_id} --all | jq -r ".data[0].id")
  echo "Scaling $cluster_id  with nodepool $node_pool_id to $pool_size"
  oci ce node-pool update --size $pool_size --node-pool-id ${node_pool_id} --force
}

get_nodes() {
  local node_count=0
  local round=0
  while [ $node_count -lt 3 ]; do
    echo "Waiting node pool to get ready attempt $round with node count $node_count"
    sleep 60
    node_count=$(kubectl get nodes --kubeconfig ${kubeconfig} | grep "Ready" | awk '{print $1}' | wc -l)
    ((round++))
  done
  echo "Got $node_count ready"
}

while [ -n "$1" ]; do # while loop starts
  case "$1" in
  --input-cli)
    cli_input
    ;;
  --input-file)
    input_file_path="$2"
    echo -e "Following path for input file is provided $input_file_path"
    user_input $input_file_path
    echo "Using following json"
    cat $input_file_path
    shift
    ;;
  --kubeconfig-path)
    kubeconfig="$PWD/$2"
    shift
    ;;
  --cluster-name)
    cluster_name="$2"
    shift
    ;;
  --namespace)
    cluster_namespace="$2"
    shift
    ;;
  --scale-up)
    deployment_state="START"
    shift
    ;;
  --scale-down)
    deployment_state="STOP"
    shift
    ;;
  --)
    shift # The double dash makes them parameters
    break
    ;;
  *) echo -e "Option $1 not recognized" ;;
  esac
  shift
done

compartment_id=${compartment_id:-$1}

if [ -z "$kubeconfig" ]; then
  echo -e "No valid kubeconfig path provided exiting...."
  exit 1
fi

cluster_list=$(oci ce cluster list -c $compartment_id --all)
echo $cluster_list >oci_cluster_list.json
while read i; do
  cluster_identity=$(echo "${i}" | jq -r '."name"')
  id=$(echo "${i}" | jq -r '."id"')
  # echo "$id, $cluster_identity, $cluster_name"
  if [ $cluster_identity == $cluster_name ]; then
    cluster_id=$id
    echo "$cluster_identity with $id Found"
    break
  fi
done <<<"$(jq -c '.data[]' oci_cluster_list.json)"

if [ -z $cluster_id ]; then
  echo "Unable to find cluster with following ID $cluster_id exiting..."
  exit 1
fi

ns_ambassador=$(kubectl get ns --kubeconfig ${kubeconfig} | grep ambassador | awk '{print $1}')
if [ -z $ns_ambassador ]; then
  kubectl create -f https://www.getambassador.io/yaml/aes-crds.yaml --kubeconfig ${kubeconfig} &&
    kubectl wait --for condition=established --timeout=90s crd -lproduct=aes --kubeconfig ${kubeconfig} &&
    kubectl create -f https://www.getambassador.io/yaml/aes.yaml --kubeconfig ${kubeconfig} &&
    kubectl -n ambassador wait --for condition=available --timeout=300s deploy -lproduct=aes --kubeconfig ${kubeconfig}
fi

if [ $deployment_state == "STOP" ]; then
  echo "Initiating pool shutdown"
  if [ ! -z $cluster_namespace ]; then
    scale_kubernetes 0 $cluster_namespace
  fi
  scale_kubernetes 0 ambassador
  # scale_kubernetes 0 default
  kubectl scale sts --replicas=0 nfs-server-provisioner --kubeconfig ${kubeconfig}
  scale_kubernetes 0 ingress-nginx
  progress_bar 120
  scale_node_pool 0 $cluster_id
  echo "Completed pool shutdown"
elif [ $deployment_state == "START" ]; then
  echo "Initiating pool startup"
  scale_node_pool 3 $cluster_id
  get_nodes
  # scale_kubernetes 1 default
  kubectl scale sts --replicas=1 nfs-server-provisioner --kubeconfig ${kubeconfig}
  progress_bar 60
  if [ ! -z $cluster_namespace ]; then
    scale_kubernetes 1 $cluster_namespace
    kubectl scale --replicas=2 deployment explorer -n $cluster_namespace --kubeconfig ${kubeconfig}
    kubectl scale --replicas=2 deployment 0proxy -n $cluster_namespace --kubeconfig ${kubeconfig}
  fi
  scale_kubernetes 1 ambassador
  echo "Completed pool startup"
fi
#  ./pre-deployment.sh --kubeconfig-path ../inventory/mycluster/artifacts/Kubeconfig_refactor.conf  --cluster-name premiumlb  --namespace refactor --scale-up
