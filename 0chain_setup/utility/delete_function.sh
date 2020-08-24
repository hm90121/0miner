#!/bin/bash
move_to_backup() {
  local cluster_name=$1
  local base_path="$PWD/../inventory/mycluster"
  cp -rf ./terraform.tfstate.d/${cluster_name} "$base_path/terraform/"
  cp -rf "$base_path/artifacts/Kubeconfig_$cluster_name.conf" "$base_path/terraform/${cluster_name}/"
}

retrieve_from_backup() {
  local cluster_name=$1
  local base_path="$PWD/../inventory/mycluster"
  cp -rf "$base_path/terraform/${cluster_name}" ./terraform.tfstate.d/
  cp -rf "$base_path/terraform/${cluster_name}/Kubeconfig_$cluster_name.conf" "$base_path/artifacts/Kubeconfig_$cluster_name.conf"
}

delete_logs() {
  local cluster_name=$1
  log_path="$PWD/../inventory/mycluster/logs/deploy_logs_$cluster_name.log"
  log_path_complete="$PWD/../inventory/mycluster/logs/complete_logs_$cluster_name.log"
  rm $log_path $log_path_complete
}

delete_namespaces() {
  local cluster_name=$1
  local kubeconfig=$2
  kubectl delete -f https://www.getambassador.io/yaml/aes-crds.yaml --kubeconfig ${kubeconfig}
  kubectl delete -f https://www.getambassador.io/yaml/aes.yaml --kubeconfig ${kubeconfig}
  kubectl delete ns ambassador --kubeconfig=$kubeconfig

  kubectl delete ns ingress-nginx --kubeconfig=$kubeconfig
  kubectl delete ns $cluster_name --kubeconfig=$kubeconfig
  kubectl delete -f "$PWD/../0chain_setup/nfs/delete_nfs.yml" --kubeconfig ${kubeconfig}
}

wait_for_ns_delete() {
  echo "Waiting for namespace deletion"
  local cluster_name=$1
  local timeout=$2
  local kubeconfig=$3

  sleep $timeout

  ip_attempt=1
  while [ $ip_attempt -le 10 ]; do
    is_ambassador=$(kubectl get namespace --kubeconfig ${kubeconfig} | grep "ambassador")
    is_deployed=$(kubectl get namespace --kubeconfig ${kubeconfig} | grep "$cluster_name")
    is_nginx=$(kubectl get namespace --kubeconfig ${kubeconfig} | grep "ingress-nginx")
    # echo "$is_ambassador ** $is_deployed ** $is_nginx"
    if [[ -z $is_ambassador && -z $is_deployed && -z $is_nginx ]]; then
      break
    else
      echo "Waiting to delete K8s resources in cluster attempt $ip_attempt"
      sleep 60
    fi
    ((ip_attempt++))
  done
  kubectl delete pvc data-nfs-server-provisioner-0 -n default --kubeconfig ${kubeconfig}
}

delete_dns_mapping() {
  local host_address=$1
  local host_ip=$2
  local record_type=$3
  local cluster_name=$4

  host_url=${host_address} host_ip=${host_ip} record_type=${record_type} envsubst <delete_aws_dns_mapping.template >delete_dns_mapping_$cluster_name.json
  aws route53 change-resource-record-sets --hosted-zone-id $host_zone_id --change-batch file://delete_dns_mapping_$cluster_name.json
  rm delete_dns_mapping_$cluster_name.json
}

delete_lb_aws() {
  local domain_name=$1
  local domain_ip=$2
  local flag=0

  lb_list=$(aws elb describe-load-balancers)
  echo $lb_list >aws_lb_list.json
  if [ -z $domain_ip ]; then
    domain_ip=$(getent hosts $domain_name | awk '{ print $2 }' | head -n 1)
  fi
  blobber_domain_ip=$(getent hosts blobbers.$domain_name | awk '{ print $2 }' | head -n 1)
  while read i; do
    ip=$(echo "${i}" | jq -r '."DNSName"')
    id=$(echo "${i}" | jq -r '."LoadBalancerName"')
    # echo $ip $domain_ip
    if [[ $ip == $domain_ip || $ip == $blobber_domain_ip ]]; then
      flag=1
      aws elb delete-load-balancer --load-balancer-name $id
      echo "$domain_name with ip: $ip & load-balancer-id: $id deleted"
    fi
  done <<<"$(jq -c '.LoadBalancerDescriptions[]' aws_lb_list.json)"
  if [ $flag == 0 ]; then
    echo "Some error occured while Deleting load-balancer"
  fi
}

delete_lb_oci() {
  local compartment_id="ocid1.tenancy.oc1..aaaaaaaau4uzaar4poyqhwxoh5ielbcs53fu3ttv45s3bv6nkxxsudris5eq"
  local compartment_id=${compartment_id:-$1}
  local domain_name=$1
  local domain_ip=$2
  local flag=0

  lb_list=$(oci lb load-balancer list -c $compartment_id --all)
  echo $lb_list >oci_lb_list.json
  if [ -z $domain_ip ]; then
    domain_ip=$(getent hosts $domain_name | awk '{ print $1 }')
  fi
  # blobber_domain_ip=$(getent hosts blobbers.$domain_name | awk '{ print $1 }')
  while read i; do
    ip=$(echo "${i}" | jq -r '."ip-addresses" | .[0]."ip-address" ')
    id=$(echo "${i}" | jq -r '."id"')
    echo "ip: $ip dip: $domain_ip"
    if [[ $ip == $domain_ip ]]; then
      flag=1
      oci lb load-balancer delete --load-balancer-id $id --force
      echo "$domain_name with ip: $ip & load-balancer-id: $id deleted"
    fi
  done <<<"$(jq -c '.data[]' oci_lb_list.json)"
  if [ $flag == 0 ]; then
    echo "Some error occured while Deleting load-balancer"
  fi
  sleep 60;
}
