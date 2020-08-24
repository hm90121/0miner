#!/usr/bin/env bash
memory=${1:-"6144"}
disk=${2:-"50g"}

component='Select the on-prem environment: '
options=("minikube" "microk8s")
select environment in "${options[@]}"; do
  case $environment in
  "minikube")
    echo "You have Selected: minikube"
    break
    ;;
  "microk8s")
    echo "You have Selected: microk8s"
    break
    ;;
  "Quit")
    break
    ;;
  *) echo "invalid option $REPLY" ;;
  esac
done
if [[ $environment == "microk8s" ]]; then
  read -p "Provide your external/host IP: " host_ip
  echo "This may take some time, please wait..."
  microk8s stop
  microk8s start
  microk8s enable cilium dns storage metallb
  microk8s enable host-access:ip=${host_ip}
  echo "Enabled micr0k8s on your system"
  exit
fi

component='Select your operating system: '
options=("windows" "mac" "ubuntu")
select os in "${options[@]}"; do
  case $os in
  "ubuntu")
    echo "You have Selected ubuntu & docker driver will be used"
    driver="docker"
    break
    ;;
  "mac")
    echo "You have Selected mac & hyperkit driver will be used"
    driver="hyperkit"
    # extra_options="--hyperkit-vpnkit-sock=''"
    break
    ;;
  "windows")
    echo "You have Selected: windows & hyperv driver will be used"
    driver="hyperv"
    break
    ;;
  "Quit")
    break
    ;;
  *) echo "invalid option $REPLY" ;;
  esac
done

echo "Other driver options are: virtualbox, vmwarefusion, kvm2, vmware, none, docker, podman" 
read -p "If you like to use other driver please specify else leave empty: " driver_native
[ ! -z $driver_native ] && driver=$driver_native

minikube delete
minikube start --memory=${memory} --disk-size=${disk} --driver=${driver} --enable-default-cni --network-plugin=cni ${extra_options}
echo -e "\e[31m Minikube Ip for host address is $(minikube ip)\e[39m"
minikube addons enable metallb
kubectl create -f https://raw.githubusercontent.com/cilium/cilium/1.7.5/install/kubernetes/quick-install.yaml

# https://medium.com/@atsvetkov906090/enable-network-policy-on-minikube-f7e250f09a14
