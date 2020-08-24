#!/bin/bash

if ! [ -x "$(command -v git)" ]; then
  echo -e "jq  is not installed"
  sudo apt install -y jq
fi

os_version=$(uname -s)
if [ "$os_version" == "Darwin" ]; then
  if [ -f /usr/local/bin/kubectl ]; then
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version
  fi
  brew install gettext
  brew link --force gettext
  pip3 install -r ../contrib/inventory_builder/requirements.txt
  pip install netaddr
elif [ "$(expr substr $os_version 1 5)" == "Linux" ]; then
  if [ -f /etc/debian_version ]; then
    echo "Checking prerequisites..."
    if [ $(dpkg-query -W -f='${Status}' kubectl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
      sudo apt update
      echo -e "Installing kubectl the linux server...,"
      sudo apt-get install -y apt-transport-https
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
      echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
      sudo apt-get update
      sudo apt-get install -y kubectl
    fi
  fi
fi
if [[ $(python --version 2>&1) =~ 2\.7 ]]; then
  echo "Python 2.7 is already there "
else
  echo "Python 2.7 is not installed"
  sudo apt install -y python-minimal
fi
if ! [ -x "$(command -v jq)" ]; then
  echo "jq is not installed"
  sudo apt install -y jq
fi
if ! [ -x "$(command -v terraform)" ]; then
  echo "Terraform is not installed"
  sudo bash terraform-install.sh
fi
