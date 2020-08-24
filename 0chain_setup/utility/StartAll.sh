#!/bin/bash
delay_time ()
{
delay=${delay:-1}
os_version=`uname -s`
if [ "$os_version" == "Darwin" ]; then
st=$( expr 60 '*' "$delay" )
sleep ${st}
elif [ "$(expr substr $os_version 1 5)" == "Linux" ]; then
sleep ${delay}m
fi 
}
read -p "Enter the name space: " ns
read -p "Enter the downtime in minutes[default:- 1m]: " delay
echo -e "Checking the 0chain components: \n"
options=("miner" "sharder" "blobber" "validator")
for opt in "${options[@]}"
do
STS=`kubectl get deployment -n 0chain | grep $opt`
if [[ -z $STS ]]; then
echo "No deployments for $opt available"
else
echo -e "Updating the $opt component...,\n"
ZC=`kubectl get deployment --no-headers -o custom-columns=":metadata.name" -n $ns | grep $opt | wc -l`
  for n in `seq $ZC`; do
    kubectl scale deployment/${opt}-${n} --replicas=1 -n $ns
    delay_time
    kubectl get deployment/${opt}-${n} -n $ns
  done
fi
done
Zbox_STS=`kubectl get deployment -n 0chain | 0box`
if [[ -z $Zbox_STS ]]; then
echo "No deployments for 0box available"
else
echo -e "Updating the 0box component...,\n"
kubectl scale deployment/0box --replicas=1 -n $ns
fi
