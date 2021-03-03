spinner() {
  SECONDS=0
  while [[ SECONDS -lt 100 ]]; do
    for ((i = 0; i < ${#chars}; i++)); do
      sleep 0.5
      echo -e -en "${chars:$i:1}" "\r"
    done
  done
}

append_logs() {
  local text=$1
  script_index=${script_index:-0}
  if [[ -z "$2" || "$2" != "skip_count" ]]; then
    echo "$script_index.$step_count) $text" >>$log_path
    ((step_count++))
  else
    echo "$text" >>$log_path
  fi
}

progress_bar_fn() {
  local DURATION=$1
  local INT=0.25 # refresh interval

  local TIME=0
  local CURLEN=0
  local SECS=0
  local FRACTION=0

  local FB=2588 # full block

  trap "echo -e $(tput cnorm); trap - SIGINT; return" SIGINT

  echo -ne "$(tput civis)\r$(tput el)│" # clean line

  local START=$(date +%s%N)

  while [[ $SECS -lt $DURATION ]]; do
    local COLS=$(tput cols)

    # main bar
    local L=$(bc -l <<<"( ( $COLS - 5 ) * $TIME  ) / ($DURATION-$INT)" | awk '{ printf "%f", $0 }')
    local N=$(bc -l <<<$L | awk '{ printf "%d", $0 }')

    [ $FRACTION -ne 0 ] && echo -ne "$(tput cub 1)" # erase partial block

    if [ $N -gt $CURLEN ]; then
      for i in $(seq 1 $((N - CURLEN))); do
        echo -ne \\u$FB
      done
      CURLEN=$N
    fi

    # partial block adjustment
    FRACTION=$(bc -l <<<"( $L - $N ) * 8" | awk '{ printf "%.0f", $0 }')

    if [ $FRACTION -ne 0 ]; then
      local PB=$(printf %x $((0x258F - FRACTION + 1)))
      echo -ne \\u$PB
    fi

    # percentage progress
    local PROGRESS=$(bc -l <<<"( 100 * $TIME ) / ($DURATION-$INT)" | awk '{ printf "%.0f", $0 }')
    echo -ne "$(tput sc)"                  # save pos
    echo -ne "\r$(tput cuf $((COLS - 6)))" # move cur
    echo -ne "│ $PROGRESS%"
    echo -ne "$(tput rc)" # restore pos

    TIME=$(bc -l <<<"$TIME + $INT" | awk '{ printf "%f", $0 }')
    SECS=$(bc -l <<<$TIME | awk '{ printf "%d", $0 }')

    # take into account loop execution time
    local END=$(date +%s%N)
    local DELTA=$(bc -l <<<"$INT - ( $END - $START )/1000000000" |
      awk '{ if ( $0 > 0 ) printf "%f", $0; else print "0" }')
    sleep $DELTA
    START=$(date +%s%N)
  done

  echo $(tput cnorm)
  trap - SIGINT
}

progress_bar() {
  if [[ $development == true ]]; then # If development mode is enabled then progress bar will be shown
    progress_bar_fn $1
  else
    sleep $1
  fi
}

clean_name() {
  local a=${1//[^[:alnum:]]/}
  echo "${a,,}"
}

add_delay() {
  declare -A arrayzchain

  for miner_index in $(seq 1 $m); do
    # n=m$delay
    delay=$1 # in ms
    miner_index=$(validate_port $miner_index)
    arrayzchain+=(["miner-$miner_index"]="$delay")
  done
  # echo "${arrayzchain[*]}"
  echo -e "delay:" >Keygen/n2n_delay.yaml
  for from in ${!arrayzchain[@]}; do
    for to in ${!arrayzchain[@]}; do
      if [[ "${arrayzchain[$from]}" -gt "${arrayzchain[$to]}" ]]; then
        max="${arrayzchain[$from]}"
      else
        max="${arrayzchain[$to]}"
      fi
      if [ "$from" != "$to" ] && [ "$from" != "sharder-*" ]; then
        cat <<EOF >>Keygen/n2n_delay.yaml
  - from: $from
    to: $to
    time: $max 

EOF
      fi
    done
  done
}

create_configmap() {
  local file_path=$1
  local svc_name=$2
  local envsubst_cmd=$3
  $envsubst_cmd
  if [ -f $file_path ]; then
    echo -e "\e[32m Creating kubernetes Configmap for $svc_name..\n \e[39m"
    kubectl create -f $file_path --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
    # echo -e "\e[32m Creating kubernetes ..\n \e[39m"
  else
    echo "File $file_path not found retrying & waiting..."
    sleep 5
    $envsubst_cmd
    sleep 5
    kubectl create -f $file_path --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
  fi
}

create_bucket() {
  echo -e "\e[93m =================== Creating cloud storage bucket =================== \e[39m"
  append_logs "Creating storage bucket for backup"
  access_key_id=$ACCESS_KEY_ID && secret_access_key=$SECRET_ACCESS_KEY && bucket_url=$BUCKET_URL && bucket_region=$BUCKET_REGION && sharder_bucket_name=$SHARDER_BUCKET_NAME && blobber_bucket_name=$BLOBBER_BUCKET_NAME

  local cloud_provider=$1
  local enable_archive=$2

  # echo "$bucket_region $bucket_name $bucket_url $access_key_id $secret_access_key"
  if [[ -z $bucket_region || -z $bucket_url || -z $access_key_id || -z $secret_access_key ]]; then
    bucket_url="play.min.io"
    bucket_name="mytestbucket"
    access_key_id="Q3AM3UQ867SPQQA43P2F"
    secret_access_key="zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG"
    bucket_region="us-east-1"
  fi
  if [[ $enable_archive != true ]]; then
    bucket_url=${bucket_url} bucket_name=${sharder_bucket_name} access_key_id=${access_key_id} secret_access_key=${secret_access_key} bucket_region=${bucket_region} \
      envsubst <Sharders_tmplt/Configmap/configmap-minio.template >k8s-yamls/sharder-secret-minio-${cluster}.yaml
    create_configmap k8s-yamls/sharder-secret-minio-${cluster}.yaml minio
    sleep 5 && rm k8s-yamls/sharder-secret-minio-${cluster}.yaml

    bucket_url=${bucket_url} bucket_name=${blobber_bucket_name} access_key_id=${access_key_id} secret_access_key=${secret_access_key} bucket_region=${bucket_region} \
      envsubst <Blobbers_tmplt/Configmap/configmap-minio.template >k8s-yamls/blobber-secret-minio-${cluster}.yaml
    create_configmap k8s-yamls/blobber-secret-minio-${cluster}.yaml minio
    sleep 5 && rm k8s-yamls/blobber-secret-minio-${cluster}.yaml
  fi
}


deploy_rook_ceph() {
  pushd rook-ceph/0chain
  if [[ "$count" -gt "3" ]]; then
    osd_count="$count"
  else
    osd_count=3
  fi
  count=${osd_count} envsubst <prime-cluster.tmplt >prime-cluster.yaml
  storage_class=$(kubectl get storageclasses.storage.k8s.io -n rook-ceph --kubeconfig ${kubeconfig} | grep "csi-cephfs")
  if [[ -z "$storage_class" && $cloud_provider != "on-premise" ]]; then
    echo -e "\e[93m =================== Creating the Storage class Rook-ceph =================== \n \e[39m"
    append_logs "Creating kubernetes storage class ${storage_class}"
    for file in $(ls *.yaml -p | grep -v /); do
      # ls ${file}
      kubectl create -f ${file} --kubeconfig $kubeconfig $KUBE_EXTRA_ARGS
      sleep 5
    done
    echo -e "\e[32m Creating storage class csi-cephfs, this may take few minutes \e[39m"
    progress_bar 60
  else
    echo -e "\e[32m Storage class csi-cephfs already exist \e[39m"
  fi
  popd
}

cluster_reset() {
  cluster=$1
  kubeconfig=$2

  if [[ $standalone != true ]]; then
    pushd Load_balancer
    kubectl delete -f ./Ambassador/ambassador-aes.yaml --kubeconfig ${kubeconfig}
    kubectl delete -f ./Ambassador/ambassador-aes-crds.yaml --kubeconfig ${kubeconfig}
  fi

  local ns_nginx=$(kubectl get ns --kubeconfig ${kubeconfig} | grep "ingress-nginx")
  if [[ ! -z $ns_nginx ]]; then
    pushd Load_balancer
    kubectl delete -f ./nginx/k8s-yamls/ --kubeconfig ${kubeconfig}
    kubectl delete ns ingress-nginx
  fi
  popd

  helm ls -A --all-namespaces | awk 'NR > 1 { print  "-n "$2, $1}' | xargs -L1 helm delete
  kubectl delete all --all -n monitoring
  kubectl delete all --all -n cattle-system
  kubectl delete all --all -n elastic-system
  kubectl delete ns monitoring
  kubectl delete ns cattle-system
  kubectl delete ns elastic-system
  kubectl delete all --all -n ${cluster}
  kubectl delete ns ${cluster} --kubeconfig ${kubeconfig}
  kubectl delete all --all -n cert-manager
  kubectl delete ns cert-manager
}

validate_port() {
  if [[ $1 -lt 10 ]]; then
    echo "0$1"
  else
    echo $1
  fi
}

expose_port() {
  for n in $(seq $SP $(($2 + $EP))); do
    n=$(validate_port $n)
    echo -e "\e[36m Exposing service $3-$n on $host_address:$1$n\e[39m"
    cat <<EOF >>./k8s-yamls/ambassador_svc_patch.yaml
  - name: "$1$n"
    nodePort: $1$n
    port: $1$n
    protocol: TCP
EOF
  done
}

expose_svc_list() {
  svc_list="${NEWLINE}"
  local service_name=$5
  total_count=$(validate_port $2)
  if [ $3 == "JSON" ]; then
    for n in $(seq $SP $(($2 + $EP))); do
      n=$(validate_port $n)
      if [ $4 == "EXT" ]; then
        svc_list="$svc_list ${SPACES8}\"http://$host_address:$1$n/\""
      elif [ $4 == "INT" ]; then
        svc_list="$svc_list ${SPACES8}\"$service_name-$n:$1$n/\""
      fi
      if [ $n != $total_count ]; then
        svc_list="$svc_list,${NEWLINE}"
      fi
    done
  elif [ $3 == "YAML" ]; then
    for n in $(seq $SP $(($2 + $EP))); do
      n=$(validate_port $n)
      if [ $4 == "EXT" ]; then
        svc_list="$svc_list ${SPACES4}- http://$host_address:$1$n"
      elif [ $4 == "INT" ]; then
        svc_list="$svc_list ${SPACES4}- $service_name-$n:$1$n"
      fi
      if [ $n != $2 ]; then
        svc_list="$svc_list${NEWLINE}"
      fi
    done
  fi
  echo "$svc_list"
}

k8s_deply() {
  local service_dir=$1
  local index=$2
  local duration=$3
  local is_auxiliary=$4
  local num_nodes=$node_count

  pushd $service_dir
  mkdir -p k8s-yamls
  rm -f k8s-yamls/*

  [[ ! -z $dtype && $dtype == "PRIVATE" ]] && config_dir="Configmap_enterprise" || config_dir="Configmap"
  [[ ! -z $standalone && $standalone == true ]] && deploy_dir="Deployments" || deploy_dir="Deployments"

  for file in $(ls $config_dir); do
    if [[ $file == *.yaml ]]; then
      kubectl create -f $config_dir/${file} --kubeconfig $kubeconfig --namespace $cluster
      echo -e "\e[32m Creating kubernetes Configmap ${file} for $service_dir from ${config_dir}... \e[39m"
    fi
  done

  for n in $(seq $SP $(($index + $EP))); do
    n=$(validate_port $n)
    [[ $is_auxiliary == true ]] && n=$node_count
    # [[ -z $is_auxiliary || $is_auxiliary == null ]] && num_nodes=$(($node_count - 1))
    [[ $is_auxiliary == false && $node_count != 1 ]] && num_nodes=$(($node_count - 1))
    echo -e "\e[36m Creating service deployment $service_dir-\e[1m$n \e[39m"
    append_logs "Creating service deployment $service_dir-$n" "skip_count"
    if [ -d "Volumes" ]; then
      for file in $(ls Volumes); do
        echo -e "\e[32m Creating kubernetes volume yamls from template.. \e[39m"
        n=${n} fs_type=${fs_type} rwm_sc=${rwm_sc} data_volume_size=${data_volume_size} log_volume_size=${log_volume_size} envsubst <Volumes/${file} >k8s-yamls/volume-${n}-${file}
        n=${n} kubectl create -f k8s-yamls/volume-${n}-${file} --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
        echo -e "\e[32m Creating kubernetes Volumes.. \e[39m ${NEWLINE}"
      done
    fi
    for file in $(ls $deploy_dir); do
      if [[ $file == *.yaml ]]; then
        echo -e "\e[32m Creating kubernetes Deployments yamls from template.. \e[39m"
        host_address=${host_address} n=${n} REGISTRY_IMAGE=${REGISTRY_IMAGE} TAG=${TAG} envsubst <$deploy_dir/${file} >k8s-yamls/deployment-${n}-${file}
        python3 ../update_label.py k8s-yamls/deployment-${n}-${file} $num_nodes $n
        n=${n} kubectl create -f k8s-yamls/deployment-${n}-${file} --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
        echo -e "\e[32m Creating kubernetes Deployments ${file} for $service_dir from ${deploy_dir}.. \e[39m ${NEWLINE}"
        sleep $duration
      fi
    done
    for file in $(ls Services); do
      echo -e "\e[32m Creating kubernetes Services yamls from template.. \e[39m"
      n=${n} envsubst <Services/${file} >k8s-yamls/service-${n}-${file}
      n=${n} kubectl create -f k8s-yamls/service-${n}-${file} --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
      echo -e "\e[32m Creating kubernetes Services.. \e[39m ${NEWLINE}"
    done
    if [ -d "Statefullset" ]; then
      for file in $(ls Statefullset); do
        echo -e "\e[32m Creating kubernetes Statefullset yamls from template.. \e[39m"
        n=${n} fs_type=${fs_type} data_volume_size=${data_volume_size} envsubst <Statefullset/${file} >k8s-yamls/Statefullset-${n}-${file}
        n=${n} kubectl create -f k8s-yamls/Statefullset-${n}-${file} --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
        echo -e "\e[32m Creating kubernetes Statefullset.. \e[39m ${NEWLINE}"
      done
    fi
    # [ $cloud_provider == "on-premise" ] && sleep 10
  done
  popd
}

unit_deploy() {
  echo "WIP"
}

patch_ngnix_lb() {
  echo -e "\e[93m =================== Patching NGINX for TCP & URL Mappings =================== \e[39m"

  if [[ ! -f k8s-yamls/chain_ingress.yaml ]]; then
    # cluster=${cluster} envsubst <nginx_cm_tcp.template >k8s-yamls/nginx_cm_tcp.yaml
    # envsubst <nginx_svc_patch.template >k8s-yamls/nginx_svc_patch.yaml
    host_address=${host_address} cluster=${cluster} envsubst <chain_ingress.template >k8s-yamls/chain_ingress.yaml
  fi
  for n in $(seq $SP $(($2 + $EP))); do
    n=$(validate_port $n)
    local svc_name=$3-$n
    local svc_port=$1$n
    # echo -e "$exposed_port_list Exposing service $svc_name on $host_address:$svc_port"

#     cat <<EOF >>./k8s-yamls/nginx_cm_tcp.yaml
#   $svc_port: "${cluster}/$svc_name:$svc_port"
# EOF

#     cat <<EOF >>./k8s-yamls/nginx_svc_patch.yaml
#   - name: "$svc_port"
#     nodePort: $svc_port
#     port: $svc_port
#     protocol: TCP
# EOF

#     cat <<EOF >>./k8s-yamls/ingress.yaml
#   $svc_port: "${cluster}/$svc_name:$svc_port"
# EOF

    cat <<EOF >>./k8s-yamls/chain_ingress.yaml
      - path: /$3$n/(|$)(.*)
        backend:
          serviceName: $3-$n
          servicePort: $1$n
EOF
  done

}

patch_services() {

  echo -e "\e[93m =================== Patching Services =================== \e[39m"

  for n in $(seq $SP $(($2 + $EP))); do
    n=$(validate_port $n)
    local svc_name=$3-$n
    local svc_port=$1$n

    echo $svc_name"-------"$svc_port
    cat <<EOF >>./patch_service.sh
kubectl -n $cluster patch svc $svc_name --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":$svc_port}]'
EOF
  done
}



patch_ambassador() {
  if [[ $cloud_provider == "on-premise" && ! -z $host_ip ]]; then
    pushd metallb
    echo -e "\e[32m Patching metalb for external IP ${host_ip}\e[39m"
    host_ip=${host_ip} envsubst <metallb_config.template >metallb_config.yaml
    kubectl apply -f metallb_config.yaml --namespace metallb-system --kubeconfig $kubeconfig
    # kubectl -n ambassador patch svc ambassador --patch "$(cat k8s-yamls/ambassador_svc_eip_patch.yaml)" --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
    popd
  fi

  pushd Ambassador
  mkdir -p k8s-yamls && rm -f k8s-yamls/*

  echo -e "\e[93m =================== Patching ambassador for TCP & URL Mappings =================== \e[39m"

  ambassador_svc_http_port=$(kubectl get -n ambassador service ambassador --kubeconfig ${kubeconfig} -o 'go-template={{range .spec.ports}}{{if eq .name "http" }}{{print .nodePort}}{{end}}{{end}}')
  ambassador_svc_https_port=$(kubectl get -n ambassador service ambassador --kubeconfig ${kubeconfig} -o 'go-template={{range .spec.ports}}{{if eq .name "https" }}{{print .nodePort}}{{end}}{{end}}')
  ambassador_svc_http_port=${ambassador_svc_http_port} ambassador_svc_https_port=${ambassador_svc_https_port} envsubst <ambassador_svc_patch.template >k8s-yamls/ambassador_svc_patch.yaml

  if [[ $s =~ ^[0-9]+$ && $s -gt 0 && $s -le 99 ]]; then
    expose_port 311 $s Sharder # 311**
    for n in $(seq $SP $(($s + $EP))); do
      n=$(validate_port $n)
      n=${n} envsubst <sharder-ambassador.yaml >k8s-yamls/sharder-ambassador-${n}.yaml
      n=${n} kubectl create -f k8s-yamls/sharder-ambassador-${n}.yaml --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
    done
  fi
  if [[ $m =~ ^[0-9]+$ && $m -gt 0 && $m -le 99 ]]; then
    expose_port 312 $m Miners # 312**
    for n in $(seq $SP $(($m + $EP))); do
      n=$(validate_port $n)
      n=${n} envsubst <miner-ambassador.yaml >k8s-yamls/miner-ambassador-${n}.yaml
      n=${n} kubectl create -f k8s-yamls/miner-ambassador-${n}.yaml --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
    done
  fi
  if [[ $b =~ ^[0-9]+$ && $b -gt 0 && $b -le 99 ]]; then
    if [ ! $b -gt $blobber_limit ]; then
      expose_port 313 $b Blobber # 313**
      for n in $(seq $SP $(($b + $EP))); do
        n=$(validate_port $n)
        n=${n} envsubst <blobber-ambassador.yaml >k8s-yamls/blobber-ambassador-${n}.yaml
        n=${n} kubectl create -f k8s-yamls/blobber-ambassador-${n}.yaml --kubeconfig $kubeconfig --namespace $cluster $KUBE_EXTRA_ARGS
      done
    else
      popd
      create_dns_mapping ingress-nginx
      pushd nginx
      patch_ngnix_lb 313 $b Blobber
      popd
      pushd Ambassador
    fi
  fi

  sleep 5
  # Expose Tcp Mappings
  kubectl -n ambassador patch svc ambassador --patch "$(cat k8s-yamls/ambassador_svc_patch.yaml)" --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
  exposed_port_list="$exposed_port_list Exposing explorer on $host_address:80${NEWLINE}"
  echo -e "\e[32m $exposed_port_list"

  sleep 5
  # Disable https and ssl
  host_address=${host_address} envsubst <ambassador_hosts.yaml >k8s-yamls/ambassador_hosts.yaml
  kubectl create -f k8s-yamls/ambassador_hosts.yaml --kubeconfig $kubeconfig

  sleep 5
  # Expose Url Mappings
  # kubectl create -f explorer-ambassador.yaml --namespace $cluster --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
  # kubectl create -f recorder-ambassador.yaml --namespace $cluster --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
  # kubectl create -f worker-ambassador.yaml --namespace $cluster --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
  # kubectl create -f 0proxy-ambassador.yaml --namespace $cluster --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
  kubectl create -f ambassador_path_mapping.yaml --namespace $cluster --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS

  echo -e "\e[32m Completed Patching Load balancer \e[39m"
  popd
}

bounce_pods() {
  local namespace=$2
  namespace=${namespace:-$cluster}
  pod_list=$(kubectl get pods -o custom-columns='NAME:metadata.name' --namespace $namespace --kubeconfig ${kubeconfig} | grep $1)
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

cli_input_deployment() {
  echo -e "Requesting user input from console"
  read -p "Enter the 0chain cluster name: " cluster
  read -p "Enter the number of Sharders: " s
  read -p "Enter the number of Miners: " m
  read -p "Enter the number of Blobbers: " b
  read -p "Do you need main component? [y/N]: " deploy_main
  read -p "Do you need auxiliary component? [y/N]: " deploy_auxiliary
  read -p "Provide the kube public DNS name[Optional] : " host_name
  read -p "Enter your kubeconfig complete path [optional]: " kubeconfig
  read -p "Do you need to add n2n_delay? [y/N]: " n2n_delay
  read -p "Please specify file system type? [gp2/csi-cephfs/sc1]: " fs_type
  read -p "Please specify cloud provider? [oci/aws/on-premise]: " cloud_provider
  read -p "Please Specify Dns record type? [A/CNAME]: " record_type
  # host_name="${host_name:-$(cat $PWD/../inventory/mycluster/artifacts/public_host.txt)}"
}

user_input_deployment() {
  input_file_path="$1"
  echo $pwd
  json_source=${input_file_path:-aws_input.json}
  cluster=$(jq -r .cluster_name $json_source)
  s=$(jq -r .sharder_count $json_source)
  m=$(jq -r .miner_count $json_source)
  b=$(jq -r .blobber_count $json_source)
  deploy_main=$(jq -r .deploy_main $json_source)
  deploy_auxiliary=$(jq -r .deploy_auxiliary $json_source)
  host_name=$(jq -r .host_address $json_source)
  kubeconfig=$(jq -r .kubeconfig_path $json_source)
  n2n_delay=$(jq -r .n2n_delay $json_source)
  fs_type=$(jq -r .fs_type $json_source)
  REGISTRY_IMAGE=$(jq -r .repo_type $json_source)
  TAG=$(jq -r .image_tag $json_source)
  cloud_provider=$(jq -r .cloud_provider $json_source)
  record_type=$(jq -r .record_type $json_source)
  dtype=$(jq -r .deployment_type $json_source)
  elk=$(jq -r .monitoring.elk $json_source)
  rancher=$(jq -r .monitoring.rancher $json_source)
  grafana=$(jq -r .monitoring.grafana $json_source)
  kibana_domain=$(jq -r .monitoring.elk_address $json_source)
  rancher_domain=$(jq -r .monitoring.rancher_address $json_source)
  grafana_domain=$(jq -r .monitoring.grafana_address $json_source)
  on_premise=$(jq -r .on_premise $json_source)
  if [[ ! -z "$on_premise" || $on_premise != null ]]; then
    on_prem_env=$(jq -r .on_premise.environment $json_source)
    host_ip=$(jq -r .on_premise.host_ip $json_source)
    echo "On-prem parameters are $on_prem_env && $host_ip"
  elif [[ $cloud_provider == "on-premise" ]]; then
    if [[ -z $on_prem_env || -z $host_ip ]]; then
      echo "Improper on-prem config recieved please check your on-prem values"
      exit
    fi
  fi
  is_deploy_svc=$(jq -r .deploy_svc $json_source)
  if [[ -z "$is_deploy_svc" || $is_deploy_svc == null ]]; then
    echo "Deploying all services"
  else
    is_deploy_miner=$(jq -r .deploy_svc.miner $json_source)
    is_deploy_sharder=$(jq -r .deploy_svc.sharder $json_source)
    is_deploy_blobber=$(jq -r .deploy_svc.blobber $json_source)
    is_deploy_zproxy=$(jq -r .deploy_svc.zproxy $json_source)
    is_deploy_zbox=$(jq -r .deploy_svc.zbox $json_source)
    is_deploy_worker=$(jq -r .deploy_svc.worker $json_source)
    is_deploy_recorder=$(jq -r .deploy_svc.recorder $json_source)
    is_deploy_explorer=$(jq -r .deploy_svc.explorer $json_source)
  fi
  standalone=$(jq -r .standalone $json_source)
  if [[ -z "$standalone" || $standalone == null ]]; then
    standalone=false
  else
    standalone=true
    public_key=$(jq -r .standalone.public_key $json_source)
    private_key=$(jq -r .standalone.private_key $json_source)
    network_url=$(jq -r .standalone.network_url $json_source)
    blobber_delegate_ID=$(jq -r .standalone.blobber_delegate_ID $json_source)
    read_price=$(jq -r .standalone.read_price $json_source)
    write_price=$(jq -r .standalone.write_price $json_source)
    capacity=$(jq -r .standalone.capacity $json_source)
  fi
}

# get_host() {
#   local address_type=$1
#   local blobber_count=$2
#   if [ $address_type == "external" ]; then
#     host_address="${host_name}.${domain_name}"
#   elif [ $address_type == "internal" ]; then
#     host_address="ambassador.ambassador"
#   elif [[ $address_type == "custom" ]]; then
#     if [[ $b -gt $blobber_limit ]]; then
#       host_address="blobbers.$host_address"
#     fi
#   else
#     host_address="${host_name}.${domain_name}"
#   fi
#   echo $host_address
# }

create_dns_mapping() {
  pushd Aws
  mkdir -p k8s-yamls && rm -f k8s-yamls/*
  local lb_type=$1
  local host_ip=""
  local ip_attempt=1
  append_logs "Waiting for $lb_type Ip provisioning by cloud provider"
  while [ $ip_attempt -le 16 ]; do

    if [ $lb_type == "ambassador" ]; then
      host_ip=$(kubectl get --kubeconfig ${kubeconfig} -n ambassador service ambassador -o 'go-template={{range .status.loadBalancer.ingress}}{{print .'${ip_type}' "\n"}}{{end}}')
    elif [ $lb_type == "ingress-nginx" ]; then
      host_ip=$(kubectl get --kubeconfig ${kubeconfig} -n ingress-nginx service ingress-nginx-controller -o 'go-template={{range .status.loadBalancer.ingress}}{{print .'${ip_type}' "\n"}}{{end}}')
      local host_address="blobbers.${host_name}.${domain_name}"
    fi

    if [[ -z "$host_ip" ]]; then
      echo "Waiting for $lb_type provisioning of host Ip attempt ${ip_attempt}"
      sleep 60
    elif [[ $ip_attempt -gt 15 ]]; then
      echo "Unable to provision Ip, exiting... " && exit
    else
      echo -e "\e[32m External ip for user is $host_ip \e[39m" && break
    fi
    ((ip_attempt++))
  done

  # creating Dns mapping using aws route 53
  # host_address="${host_address:-$(kubectl get -n ambassador service ambassador -o 'go-template={{range .status.loadBalancer.ingress}}{{print .hostname "\n"}}{{end}}')}"
  if [[ $cloud_provider == "aws" || $cloud_provider == "oci" ]]; then
    echo -e "\e[93m =================== Creating Dns mapping using aws route 53 =================== \e[39m" && append_logs "Updating DNS mapping for requested URL"
    record_type=$record_type
    host_url=${host_address} host_ip=${host_ip} record_type=${record_type} envsubst <aws_dns_mapping.template >k8s-yamls/"${cloud_provider}_${lb_type}_DNS_mapping.json"
    aws route53 change-resource-record-sets --hosted-zone-id $host_zone_id --change-batch file://k8s-yamls/"${cloud_provider}_${lb_type}_DNS_mapping.json"
  fi
  popd
}

expose_deployment_lb() {
  local svc_name=$1
  local deploy_count=$2
  local port=$3

  pushd Load_balancer/metallb
  echo -e "\e[32m Patching metalb for external IP ${host_ip}\e[39m"
  host_ip=${host_ip} envsubst <metallb_config.template >metallb_config.yaml
  kubectl apply -f metallb_config.yaml --namespace metallb-system --kubeconfig $kubeconfig
  # kubectl -n ambassador patch svc ambassador --patch "$(cat k8s-yamls/ambassador_svc_eip_patch.yaml)" --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
  popd

  for n in $(seq $SP $(($deploy_count + $EP))); do
    n=$(validate_port $n)
    kubectl expose deployment "$svc_name-${n}" --type=LoadBalancer --name="$svc_name-${n}-public" --port="${port}${n}" --target-port="${port}${n}" --kubeconfig ${kubeconfig} --namespace $cluster
  done
}

configure_standalone_dp() {
  local config_dir="Configmap_enterprise"
  local block_worker_url="https://${network_url}/dns"
  local port=""
  read_price=${read_price:-"0.1"}
  write_price=${write_price:-"0.1"}
  capacity=${capacity:-"1073741824"}

  if [[ $m == 1 ]]; then
    config_dir="Sharders_tmplt/$config_dir"
    for file in $(ls $config_dir); do
      if [[ $file == *.yaml ]]; then
        echo -e "\e[32m Creating kubernetes Configmap ${file}... \e[39m"
        kubectl create -f $config_dir/${file} --kubeconfig $kubeconfig --namespace $cluster
      fi
    done
    ./Keygen/standalone/keys_file --host_url ${host_address} --port " " --keys_file on-prem/wallet/owner_keys.txt
    kubectl create configmap owner-keys-config --kubeconfig ${kubeconfig} --namespace $cluster --from-file=b0owner_keys.txt=on-prem/wallet/owner_keys.txt -o yaml $KUBE_EXTRA_ARGS >k8s-yamls/owner.yaml
  fi

  mkdir -p on-prem/wallet && rm -f on-prem/wallet/*
  curl "${block_worker_url}/magic_block" >on-prem/wallet/magicBlock.json
  kubectl create configmap magic-block-config --kubeconfig ${kubeconfig} --namespace $cluster --from-file=on-prem/wallet/magicBlock.json -o yaml $KUBE_EXTRA_ARGS >k8s-yamls/magic_block.yaml

  [ $s == 1 ] && port=31101
  [ $m == 1 ] && port=31201
  [ $b == 1 ] && port=31301
  if [[ ! -z "$public_key" && $public_key != null && ! -z $private_key && $private_key != null ]]; then
    ./Keygen/standalone/keys_file --public_key ${public_key} --private_key ${private_key} --host_url ${host_address} --n2n_ip ${host_ip} --port ${port} --keys_file on-prem/wallet/wallet.txt
  else
    ./Keygen/standalone/keys_file --host_url ${host_address} --n2n_ip ${host_ip} --port ${port} --keys_file on-prem/wallet/wallet.txt
  fi

  kubectl create configmap wallet-keys-config --kubeconfig ${kubeconfig} --namespace $cluster --from-file=wallet.txt=on-prem/wallet/wallet.txt -o yaml $KUBE_EXTRA_ARGS >k8s-yamls/wallet.yaml

  if [[ $b == 1 ]]; then
    config_dir="Configmap_enterprise"
    blobber_delegate_ID=${blobber_delegate_ID} block_worker_url=${block_worker_url} read_price=${read_price} write_price=${write_price} capacity=${capacity} envsubst <Blobbers_tmplt/$config_dir/configmap-blobber-config.template >Blobbers_tmplt/$config_dir/configmap-blobber-config.yaml
  fi
}

deploy_elk_stack() {
  if [[ $elk == true ]]; then 
  echo -e "\e[93m Setting up ELK stack \e[39m" && append_logs "Setting up elk stack for logging and metric data"
  export CLUSTER=$cluster
  pushd Elk
  kubectl apply -f https://download.elastic.co/downloads/eck/1.1.2/all-in-one.yaml
  kubectl apply -f elasticsearch.yaml
  kubectl apply -f kibana.yaml
  sleep 35
  PASSWORD=$(kubectl get secret elastic-cluster-es-elastic-user -n elastic-system -o go-template='{{.data.elastic | base64decode}}')
  echo ELASTICSEARCH USER=elastic
  echo ELASTICSEARCH PASSWORD $PASSWORD

  curl --silent https://raw.githubusercontent.com/elastic/beats/7.8/deploy/kubernetes/filebeat-kubernetes.yaml | awk '$2 == "name:" { tag = ($3 == "ELASTICSEARCH_HOST") } tag && $1 == "value:"{$1 = "          " $1; $2 = "elastic-cluster-es-http"} 1' | sed "s/changeme/$PASSWORD/g" | sed "s/kube-system/elastic-system/g" | sed "s/7.8.1/7.8.0/g" | kubectl apply -f -
  curl --silent https://raw.githubusercontent.com/elastic/beats/7.8/deploy/kubernetes/metricbeat-kubernetes.yaml | awk '$2 == "name:" { tag = ($3 == "ELASTICSEARCH_HOST") } tag && $1 == "value:"{$1 = "          " $1; $2 = "elastic-cluster-es-http"} 1' | sed "s/changeme/$PASSWORD/g" | sed "s/kube-system/elastic-system/g" | sed "s/7.8.1/7.8.0/g" | kubectl apply -f -
  PASSWORD=$PASSWORD CLUSTER=$cluster envsubst <filebeat-sidecar-configmap.template >filebeat-sidecar-configmap.yaml
  kubectl apply -f filebeat-sidecar-configmap.yaml
  popd
  else
    echo "skipping elk"
  fi

resolvedIP=$(nslookup "$kibana_domain" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
[[ -z "$resolvedIP" ]] && echo "$kibana_domain" lookup failure || echo "$kibana_domain" resolved to "$resolvedIP"

  if [[ $resolvedIP ]]; then
    kubectl create -f Load_balancer/nginx/k8s-yamls/kibana-ingress.yaml --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
    echo -e "\e[32m kibana deployed at following url $kibana_domain \e[39m"
  fi
   
  if [[ -z $kibana_domain || -z $resolvedIP ]]; then
    kubectl -n elastic-system patch svc kibana-kb-http --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":30002}]'
    echo -e "\e[32m kibana deployed at following url $host_ip:30002 \e[39m"
  fi
}

deploy_rancher() {
  if [[ $rancher == true ]]; then
  echo -e "\e[93m Setting up rancher \e[39m" && append_logs "Setting up rancher dashboard"
  export CLUSTER=$cluster
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
  kubectl create namespace cattle-system
  
  helm upgrade --install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname=${rancher_domain} \
    --set ingress.tls.source="letsEncrypt" \
    --set letsEncrypt.email="anish@squareops.xyz" \
    --set letsEncrypt.environment="production"

  # kubectl annotate ingress rancher -n cattle-system kubernetes.io/ingress.class=nginx-ingress-nginx
  echo -e "\e[32m Rancher deployed at following url ${rancher_domain} \e[39m "
  else
    echo "skipping rancher"
  fi
}

deploy_grafana() {
  if [[ $grafana == true ]]; then
  echo -e "\e[93m Setting up prometheus and grafana \e[39m" && append_logs "Setting up elk stack for logging and metric data"
  export CLUSTER=$cluster
  helm repo add prometheus-com https://prometheus-community.github.io/helm-charts
  helm repo add stable https://charts.helm.sh/stable
  helm repo update
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml

  kubectl create namespace monitoring
  sed "s/cluster_name/$cluster/g" ./custom-dash-cm.yaml | kubectl apply -f -
  helm upgrade --install kube-prometheus-stack prometheus-com/kube-prometheus-stack --version 9.4.4 --set prometheusOperator.createCustomResource=false --set grafana.defaultDashboardsEnabled=false --namespace monitoring

  echo username - admin 
  echo password - prom-operator
  else
    echo "skipping grafana"
  fi
  
resolvedIP=$(nslookup "$grafana_domain" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
[[ -z "$resolvedIP" ]] && echo "$grafana_domain" lookup failure || echo "$grafana_domain" resolved to "$resolvedIP"

  if [[ $resolvedIP ]]; then
    kubectl create -f Load_balancer/nginx/k8s-yamls/grafana-ingress.yaml --kubeconfig ${kubeconfig} $KUBE_EXTRA_ARGS
    echo -e "\e[32m Grafana deployed at following url $grafana_domain \e[39m"
  fi
   
  if [[ -z $grafana_domain || -z $resolvedIP ]]; then
    kubectl -n monitoring patch svc kube-prometheus-stack-grafana --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":30001}]'
    echo -e "\e[32m Grafana deployed at following url $host_ip:30001 \e[39m"
  fi
}

# echo  "--------------------------------------------------------------------------------------------------------------------------------------------------------------------"

# kubectl create -f Dashboard/metrics_server/ --kubeconfig $kubeconfig
# kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name -n $ns2
# kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name -n $ns2 | grep "10.0.64.2" | wc -l

# aws route53 list-hosted-zones
# aws route53 change-resource-record-sets  --hosted-zone-id  /hostedzone/Z1LRKQRXQECMHD --change-batch ./aws_dns_mapping.json

# kubectl get pods -n $ns1 | grep Error | awk '{print $1}' | xargs kubectl delete pod -n $ns1
# kubectl get nodes | grep "Ready" | awk '{print $1}' |  wc -l
# explorer block-chain

# kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=10.0.10.2
# kubectl delete pod 0proxy-6d5c549484-bxdv6  --grace-period=0 --force  -n two

# if [ "$fs_type" == "sc1" ]; then
#   kubectl create -f storage_classes/sc1_aws.yaml --kubeconfig $kubeconfig --namespace $cluster
# fi
# cat Keygen/n2n_delay.txt
# host_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
# export ns1=ambassador && export ns2=ingress-nginx && export ns3=kube-system && export ns4=one && export ns5=testing
# sudo apt update && sudo apt install nfs-common -y
#  minikube start --apiserver-ips=38.32.112.214 --memory=10Gb --enable-default-cni --network-plugin=cni
# rsync -rv --max-size=100m ubuntu@hero.alphanet-0chain.net:/home/ubuntu/.minikube/ ~/.minikube/
# scp -r ubuntu@hero.alphanet-0chain.net:/home/ubuntu/.minikube/ ~/.minikube/
