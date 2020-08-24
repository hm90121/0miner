#!/bin/bash
delay_time ()
{
os_version=`uname -s`
if [ "$os_version" == "Darwin" ]; then
st=$( expr 60 '*' "$delay" )
sleep ${st}
elif [ "$(expr substr $os_version 1 5)" == "Linux" ]; then
sleep ${delay}m
fi 
}
read -p "Enter the name space: " ns
read -p "Enter the downtime: " delay
echo -e "Select the 0chain components: \n"
options=("miner" "sharder" "blobber" "validator" "0box")
select opt in "${options[@]}"
do
    case $opt in
        "miner")
            echo "You have Selected: miner"; break;;
        "sharder")
            echo "You have Selected: sharder"; break;;
        "blobber")
            echo "You have Selected: blobber"; break;;
        "validator")
            echo "You have Selected: validator"; break;;
        "0box")
            echo "You have Selected: 0box"; break;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
while :
do
ZC=3
ZC=`kubectl get deployment --no-headers -o custom-columns=":metadata.name" -n $ns | grep $opt | wc -l`
#ZC=`kubectl get deployment --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -n $ns | grep $opt | wc -l
#kubectl get deployment pods --no-headers -o custom-columns=":metadata.name"
echo -e "\nTotal number of $opt available: $ZC\n"
SHUFNO=$(( ( RANDOM % $ZC )  + 1 ))
echo -e "Randum number: $SHUFNO \n"
SHUF=`seq $SHUFNO`
echo -e "Scaling Down the $opt components, \n\n"
for n in $SHUF; do
if [[ $ZC != $n ]]; then
echo "Component is $opt-$n"
kubectl scale deployment/${opt}-${n} --replicas=0 -n $ns
kubectl rollout status -w deployment/${opt}-${n} -n $ns
kubectl get deployment/${opt}-${n} -n $ns
fi
done
echo -e "Delay is ${delay}m \n"
delay_time
echo -e "\nScaling Up the $opt components, \n\n"
for n in $SHUF; do
if [[ $ZC != $n ]]; then
kubectl scale deployment/${opt}-${n} --replicas=1 -n $ns
delay_time
kubectl get deployment/${opt}-${n} -n $ns
fi
done
done
