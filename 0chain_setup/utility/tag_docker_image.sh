#!/usr/bin/env bash

interactive_input() {
  if [[ $all != true && -z $svc_name ]]; then
    component='Select the 0chain service: '
    options=("miner" "sharder" "blobber" "validator" "0proxy" "0box" "worker" "explorer" "recorder" "manual")
    multi_deploy=("miner" "sharder" "blobber" "validator")
    select svc_name in "${options[@]}"; do
      case $svc_name in
      "miner")
        echo "You have Selected: miner"
        svc_name="miner"
        break
        ;;
      "sharder")
        svc_name="sharder"
        echo "You have Selected: sharder"
        break
        ;;
      "blobber")
        svc_name="blobber"
        echo "You have Selected: blobber"
        break
        ;;
      "validator")
        svc_name="validator"
        echo "You have Selected: validator"
        break
        ;;
      "0proxy")
        svc_name="0proxy"
        echo "You have Selected: 0proxy"
        break
        ;;
      "0box")
        svc_name="0box"
        echo "You have Selected: 0box"
        break
        ;;
      "worker")
        svc_name="block_worker"
        echo "You have Selected: worker"
        break
        ;;
      "explorer")
        svc_name="explorer"
        echo "You have Selected: explorer"
        break
        ;;
      "recorder")
        svc_name="recorder"
        echo "You have Selected: recorder"
        break
        ;;
      "manual")
        read -p "Provide the docker image name: " svc_name
        break
        ;;
      *) echo "invalid option $REPLY" ;;
      esac
    done
  fi
  [[ -z $from_organisation ]] && read -p "Provide the docker repository name to move from: " from_organisation
  [[ -z $from_tag ]] && read -p "Provide the docker image tag name to move from: " from_tag
  [[ -z $to_organisation ]] && read -p "Provide the docker repository name to move to: " to_organisation
  [[ -z $to_tag ]] && read -p "Provide the docker image tag name to move to: " to_tag
}

while [ -n "$1" ]; do # while loop starts
  case "$1" in
  --interactive)
    interactive_input
    break
    ;;
  --latest)
    latest=true
    shift
    ;;
  --input-file)
    input_file_path="$2"
    echo -e "Following path for input file is provided $input_file_path"
    user_input_deployment $input_file_path
    echo "Using following json"
    cat $input_file_path
    shift
    ;;
  --all)
    all=true
    svc_name="manual"
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

sudo docker system info | grep -E 'Username' 1>/dev/null
if [[ $? -ne 0 ]]; then
  docker login
fi

[[ -z $from_organisation || -z $to_organisation || -z $from_tag || -z $to_tag || -z $svc_name ]] && interactive_input
from_image="${from_organisation:-0chaintest}/${svc_name}:$from_tag"
to_image="${to_organisation:-0chaintest}/${svc_name}:$to_tag"

if [[ -n "$from_tag" && -n "$to_tag" && ! -z $svc_name ]]; then
  svc_array=("miner" "sharder" "blobber" "validator" "block_worker" "0proxy" "0box" "explorer" "recorder")
  if [[ $all == true ]]; then
    for svc_name in "${svc_array[@]}"; do
      from_image="${from_organisation:-0chaintest}/${svc_name}:$from_tag"
      to_image="${to_organisation:-0chaintest}/${svc_name}:$to_tag"
      echo -e "\e[93m \n Moving $svc_name from $from_image to $to_image \e[39m"
      sudo docker pull ${from_image}
      sudo docker tag ${from_image} ${to_image}
      sudo docker push ${to_image}
      if [[ $latest == true ]]; then
        echo "Pushing $svc_name with latest tag to dockerhub"
        sudo docker tag ${from_organisation}:${from_tag} ${to_organisation}:latest
        sudo docker push ${to_registry}:latest
      fi
    done
  else
    echo -e "\e[93m \n Moving from $from_image to $to_image \e[39m"
    sudo docker pull ${from_image}
    sudo docker tag ${from_image} ${to_image}
    sudo docker push ${to_image}
    if [[ $latest == true ]]; then
      sudo docker tag ${from_organisation}:${from_tag} ${to_organisation}:latest
      sudo docker push ${to_registry}:latest
      echo "Pushing the new latest tag to dockerhub"
    fi
  fi
fi
