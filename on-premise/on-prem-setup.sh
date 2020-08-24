#!/usr/bin/env bash
if [ "$(expr substr $os_version 1 5)" == "Linux" ]; then
  if [ -f /etc/debian_version ]; then
    echo "Installing prerequisites..."
    sudo apt update
    if ! [ -x "$(command -v ansible)" ]; then
      sudo apt install -y software-properties-common
      sudo apt-add-repository --yes --update ppa:ansible/ansible
      sudo apt install -y ansible python3-pip
    fi
    pip3 install -r ../contrib/inventory_builder/requirements.txt
  fi
fi

json_source="input.json"
worker_count=$(jq -r '.workers | length' $json_source)
master_ansible_host=$(jq -r .masters.ansible_host $json_source)
master_ansible_user=$(jq -r .masters.ansible_user $json_source)
masters="master ansible_host=${master_ansible_host} ansible_user=${master_ansible_user}"

for ((i = 0; i < $worker_count; i++)); do
  worker_ansible_name=$(jq -r .workers[$i].name $json_source)
  worker_ansible_host=$(jq -r .workers[$i].ansible_host $json_source)
  worker_ansible_user=$(jq -r .workers[$i].ansible_user $json_source)
  workers="${workers} ${worker_ansible_name} ansible_host=${worker_ansible_host} ansible_user=${worker_ansible_user}"$'\n'
done

masters=${masters} workers=${workers} envsubst <hosts.template >hosts

ansible-playbook -i hosts ./initial.yml  -k -K
ansible-playbook -i hosts ./kube-dependencies.yml
ansible-playbook -i hosts ./master.yml
ansible-playbook -i hosts ./configure-master.yml
if [[ $worker_count > 0 ]]; then
  ansible-playbook -i hosts ./workers.yml
else
  ansible-playbook -i hosts ./configure-master.yml
fi