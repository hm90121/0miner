#!/usr/bin/env bash
# command to execute the script
# ./expand_openebs_disk.sh  --disk-path /dev/sdb --disk-type ssd

if ! [ -x "$(command -v jq)" ]; then
  echo -e "jq  is not installed"
  sudo apt install -y jq
fi

TEST_RUN="-o yaml --dry-run=client"
KUBE_EXTRA_ARGS=""

cli_input_disk_expansion() {
  echo -e "Requesting user input from console"
  read -p "Enter the disk path: " disk_path
  read -p "Enter the disk type: " disk_type
  read -p "Enter the disk size: " disk_size
  read -p "Enter the kubernetes node name: " node_name
}

while [ -n "$1" ]; do # while loop starts
  case "$1" in
  --input-cli)
    cli_input_disk_expansion
    ;;
  --disk-path)
    disk_path="$2"
    shift
    ;;
  --disk-size)
    disk_size="$2"
    shift
    ;;
  --disk-type)
    disk_type="$2"
    shift
    ;;
  --node-name)
    node_name="$2"
    shift
    ;;
  --development)
    development=true
    ;;
  --cargs)
    disk_path=$2
    disk_type=$3
    disk_size=$4
    node_name=$5
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

if [[ -z $disk_path ]]; then
  echo "Please provide a valid disk path"
  exit 1
else
  echo -e "Following parameters has been provided Node-name: $node_name Disk-path: $disk_path "
fi

sudo wipefs -a $disk_path
sleep 60s && echo "waiting for disk cleanup..."

cstore_pool_name="cstor-disk-pool"
device_details=$(udevadm info -q property -n $disk_path)
device_details_arr=($device_details)

for i in "${!device_details_arr[@]}"; do
  if [[ "${device_details_arr[$i]}" == *"by-path"* ]]; then
    echo "Path present at index ${i}"
    device_path_li_index=${i}
  fi
done

[[ $device_path_li_index == 0 ]] && device_path_lo_index=2 && device_path_sh_index=1
[[ $device_path_li_index == 1 ]] && device_path_lo_index=2 && device_path_sh_index=0
[[ $device_path_li_index == 2 ]] && device_path_lo_index=1 && device_path_sh_index=0
device_details_arr[0]=${device_details_arr[0]#"DEVLINKS="}

val1=${device_details_arr[$device_path_sh_index]}
val2=${device_details_arr[$device_path_lo_index]}

if [[ ${#val1} -gt ${#val2} ]]; then
  swap_index=$device_path_sh_index
  device_path_sh_index=$device_path_lo_index
  device_path_lo_index=$swap_index
fi
# printf '%s\n' "${device_details_arr[@]}"
device_model=$(echo "${device_details_arr[@]}" | grep -o 'ID_MODEL=[^ ]*')
device_model=${device_model#"ID_MODEL="}
device_path_sh=${device_details_arr[$device_path_sh_index]}
device_path_lo=${device_details_arr[$device_path_lo_index]}
device_path_li=${device_details_arr[$device_path_li_index]}
disk_size=$(lsblk -ba -o SIZE,NAME | grep ${disk_path: -3} | head -1 | awk '{print $1}')
disk_type=$(echo ${disk_type:-"default"} | xargs)

disk_index=${disk_path: -3}
node_name=${node_name:-$(hostname)}
device_path_lo_id=${device_path_lo#"/dev/disk/by-id/"}
# echo $node_name, $disk_index; exit
# echo "${device_path_lo_id} $device_path_li" && exit

if [[ -z $device_model || -z $device_path_sh || -z $device_path_lo || -z $device_path_li || -z disk_size || -z disk_type ]]; then
  echo "Unable to retrieve values, exiting..."
  exit 1
fi

if [ ! -d $disk_index ]; then
  mkdir $disk_index
fi

disk_name="${node_name}-${disk_type}-${disk_index}"
device_model=${device_model} \
  disk_size=${disk_size} \
  disk_type=${disk_type} \
  disk_path=${disk_path} \
  node_name=${node_name} \
  disk_name=${disk_name} \
  device_path_sh=${device_path_sh} \
  device_path_lo=${device_path_lo} \
  device_path_li=${device_path_li} envsubst <./blockdevice.template >$disk_index/"${disk_name}-ndm.yaml"
# printf '%s\n' "${device_details_arr[@]}" && exit

kubectl apply -f $disk_index/"${disk_name}-ndm.yaml" -n openebs $KUBE_EXTRA_ARGS

spc_uid=$(kubectl describe spc ${cstore_pool_name} | grep UID | awk '{print $2}')
bd_uid=$(kubectl describe bd ${disk_name}-ndm -n openebs | grep UID | awk '{print $2}')

if [[ -z $spc_uid || -z $bd_uid ]]; then
  echo "Unable to get all required parameters"
  exit 1
else
  echo -e "Following parameters has been provided storage pool claim: $spc_uid block device id : $bd_uid "

  disk_size=${disk_size} \
    node_name=${node_name} \
    disk_name=${disk_name} \
    spc_uid=${spc_uid} \
    bd_uid=${bd_uid} envsubst <./blockdeviceclaim.template >$disk_index/"${disk_name}-claim.yaml"
  kubectl apply -f $disk_index/"${disk_name}-claim.yaml" -n openebs $KUBE_EXTRA_ARGS
fi

cstore_pod_name=$(kubectl -n openebs get pods -o wide | grep ${node_name} | grep ${cstore_pool_name} | awk '{print $1}')
if [ ! -z $cstore_pod_name ]; then
  pool_id=$(kubectl -n openebs exec -it ${cstore_pod_name} -c cstor-pool -- zpool status | grep cstor | grep ONLINE | awk '{print $1}')
  # echo "Following pool id identified ${cstore_pod_name} ${pool_id} ${device_path_lo_id}"
  kubectl -n openebs exec -it ${cstore_pod_name} -c cstor-pool -- zpool add ${pool_id} ${device_path_lo_id} -f
  kubectl exec -it ${cstore_pod_name} -n openebs -c cstor-pool -- zpool status $KUBE_EXTRA_ARGS
else
  echo "Unable to retrieve cstore pod name"
  exit
fi

csp_pod_name=$(kubectl get csp -l kubernetes.io/hostname=${node_name} -o=jsonpath="{.items[0].metadata.name}")
if [[ ! -z $csp_pod_name ]]; then
  device_path_sh=${device_path_sh} \
    disk_name=${disk_name} envsubst <./cstore.template >$disk_index/"${disk_name}-cstore.json"

  # disk_name=${disk_name} envsubst <./storage_pool.template >"${disk_name}-spc.json"
  cstore_obj=$(kubectl get csp ${csp_pod_name} -o=json | jq .)
  echo $cstore_obj | jq --argjson bd "$(<$disk_index/${disk_name}-cstore.json)" '.spec.group[].blockDevice += [$bd]' >$disk_index/"${disk_name}-cstore.json"

  spool_obj=$(kubectl get spc ${cstore_pool_name} -o=json | jq .)
  echo $spool_obj | jq --argjson bd '"'${disk_name}'-ndm"' '.spec.blockDevices.blockDeviceList += [$bd]' >$disk_index/"${disk_name}-spc.json"

  kubectl patch csp ${csp_pod_name} --type merge --patch "$(cat $disk_index/${disk_name}-cstore.json)" $KUBE_EXTRA_ARGS
  kubectl patch spc ${cstore_pool_name} --type merge --patch "$(cat $disk_index/${disk_name}-spc.json)" $KUBE_EXTRA_ARGS
else
  echo "Unable to retrieve cstore storage pool pod name"
  exit
fi
# echo "$device_model $device_path_sh $device_path_lo $device_path_li"

sleep 10
kubectl -n openebs get csp
kubectl -n openebs get spc
kubectl -n openebs get bd
kubectl -n openebs get bdc
# ./expand_openebs_disk.sh  --disk-path /dev/sdb --disk-type ssd --node-name node6 --disk-size 1
# https://github.com/openebs/openebs-docs/blob/day_2_ops/docs/cstor_add_disks_to_spc.md
