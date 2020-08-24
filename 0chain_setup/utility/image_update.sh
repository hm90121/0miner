#!/bin/bash

validate_port() {
  [[ $1 -lt 10 ]] && echo "0$1" || echo $1
}

component='Select the 0chain component: '
options=("miner" "sharder" "blobber" "validator" "0proxy" "worker" "explorer" "recorder")
multi_deploy=("miner" "sharder" "blobber" "validator")
select opt in "${options[@]}"; do
  case $opt in
  "miner")
    echo "You have Selected: miner"
    break
    ;;
  "sharder")
    echo "You have Selected: sharder"
    break
    ;;
  "blobber")
    echo "You have Selected: blobber"
    break
    ;;
  "validator")
    echo "You have Selected: validator"
    break
    ;;
  "0proxy")
    echo "You have Selected: 0proxy"
    break
    ;;
  "worker")
    echo "You have Selected: worker"
    break
    ;;
  "explorer")
    echo "You have Selected: explorer"
    break
    ;;
  "recorder")
    echo "You have Selected: recorder"
    break
    ;;
  "Quit")
    break
    ;;
  *) echo "invalid option $REPLY" ;;
  esac
done

read -p "Enter the 0chain cluster namespace: " ns
read -p "Provide the docker image tag name: " version
read -p "Provide the github organisation name [0chaintest/0chainkube]:" organisation
echo "${organisation:-0chaintest}/${opt}:$version -n $ns"
if [[ " ${multi_deploy[@]} " =~ " ${opt} " ]]; then
  read -p "Enter the 0chain component number[Example: for miner-2, number is 2]: " num
  num=$(validate_port $num)
  image_tag="${opt}-${num}"
else
  image_tag="${opt}"
fi

if [ $num == 00 ]; then
  deployment_count=$(kubectl get deployments -n $ns | grep $opt | wc -l)
  for n in $(seq 1 $(($deployment_count))); do
    num=$(validate_port $n)
    image_tag="${opt}-${num}"
    kubectl set image deployment/$image_tag $image_tag=${organisation:-0chaintest}/${opt}:$version -n $ns
  done
else
  kubectl set image deployment/$image_tag $image_tag=${organisation:-0chaintest}/${opt}:$version -n $ns
  RetVal=$?
  kubectl rollout status deployment/$image_tag -n $ns
fi

if [[ $RetVal -eq 0 ]]; then
  echo "Updated the docker image"
fi
#kubectl rollout history deployment/${opt}-${num}
