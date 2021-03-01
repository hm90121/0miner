#!/bin/bash
# set -x
# MINER=3
# SHARDER=2
# BLOBBER=4
# PUBLIC_ENDPOINT=example.com
host_address=$PUBLIC_ENDPOINT
host_ip=$PUBLIC_IP
# MPORT=707
# SPORT=717
# BPORT=727
# dtype=PUBLIC
# port=123

echo "v1.0.17"
echo ${host_address}

validate_port() {
  if [[ $1 -lt 10 ]]; then
    echo "0$1"
  else
    echo $1
  fi
}

key_gen_miner() {
  echo "${5}s:" >>/config/nodes.yaml
  for n in $(seq 1 $(($1 + 0))); do
    on=$n
    n=$(validate_port $n)
    port=${3}${n}
    path=${5}${n}
    echo -e "Creating keys for $5-${n}.. \n"
    /0chain/go/0chain.net/core/keys_file --host_url ${host_address} --n2n_ip ${host_ip} --port ${port} --path ${path} --keys_file /ms-keys/b0$4node${n}_keys.txt >>/config/nodes.yaml
    status=$?
    local n2n_ip="$5-${n}"
    [[ $DTYPE == "PUBLIC" ]] && n2n_ip=$2
    if [[ "$status" -eq "0" ]]; then
      cat <<EOF >>/config/nodes.yaml
  n2n_ip: ${n2n_ip}               
  public_ip: $2                   
  port: ${3}${n}
  path: ${5}${n}             
  description: localhost.$4${n} 
  set_index: $((${on} - 1))
EOF
    else
      echo "Key generation failed"
      exit $retValue
    fi

  done
}

key_gen() {
  echo "${5}s:" >>/config/nodes.yaml
  for n in $(seq 1 $(($1 + 0))); do
    n=$(validate_port $n)
    port=${3}${n}
    path=${5}${n}
    echo -e "Creating keys for $5-${n}.. \n"
    /0chain/go/0chain.net/core/keys_file --host_url ${host_address} --n2n_ip ${host_ip} --port ${port} --path ${path} --keys_file /ms-keys/b0$4node${n}_keys.txt >>/config/nodes.yaml
    status=$?
    local n2n_ip="$5-${n}"
    [[ $DTYPE == "PUBLIC" ]] && n2n_ip=$2
    if [[ "$status" -eq "0" ]]; then
      cat <<EOF >>/config/nodes.yaml
  n2n_ip: ${n2n_ip}              
  public_ip: $2                   
  port: ${3}${n}
  path: ${5}${n}             
  description: localhost.$4${n} 
EOF
    else
      echo "Key generation failed"
      exit $retValue
    fi

  done
}

key_gen_blobber() {
  echo "${5}s:" >>/config/nodes.yaml
  for n in $(seq 1 $(($1 + 0))); do
    n=$(validate_port $n)
    port=${3}${n}
    path=${5}${n}
    echo -e "Creating keys for $5-${n}.. \n"
    /0chain/go/0chain.net/core/keys_file --host_url ${host_address} --n2n_ip ${host_ip} --port ${port} --path ${path} --keys_file /blob-keys/b0$4node${n}_keys.txt >>/config/nodes.yaml
    status=$?
    local n2n_ip="$5-${n}"
    [[ $DTYPE == "PUBLIC" ]] && n2n_ip=$2
    if [[ "$status" -eq "0" ]]; then
      cat <<EOF >>/config/nodes.yaml
  n2n_ip: ${n2n_ip}              
  public_ip: $2                   
  port: ${3}${n}
  path: ${5}${n}             
  description: localhost.$4${n} 
EOF
    else
      echo "Key generation failed"
      exit $retValue
    fi

  done
}

if [[ "$MINER" -ne "0" ]]; then
  echo -e "Creating keys for miners \n"
  key_gen_miner $MINER $PUBLIC_ENDPOINT $MPORT m miner 
fi

if [[ "$SHARDER" -ne "0" ]]; then
  echo -e "Creating keys for sharders \n"
  key_gen $SHARDER $PUBLIC_ENDPOINT $SPORT s sharder
fi

if [[ "$BLOBBER" -ne "0" ]]; then
  echo -e "Creating keys for BLOBBER \n"
  key_gen_blobber $BLOBBER $PUBLIC_ENDPOINT $BPORT b blobber
fi
