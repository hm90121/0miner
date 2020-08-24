#!/bin/bash

compartment_id="ocid1.tenancy.oc1..aaaaaaaau4uzaar4poyqhwxoh5ielbcs53fu3ttv45s3bv6nkxxsudris5eq"
compartment_id=${compartment_id:-$1}
volume_list=$(oci bv volume list -c $compartment_id --all)
echo $volume_list > oci_volume_list.json
while read i; do
  state=$(echo "${i}" | jq -r '."lifecycle-state"')
  id=$(echo "${i}" | jq -r '."id"')
  if [ $state == "AVAILABLE" ]; then
    echo $state
    oci bv volume delete --volume-id $id --force
    echo "$id deleted"
  # else
  #   echo "Volume with id $id gave following status $status";  
  fi
done <<< "$(jq -c '.data[]' oci_volume_list.json)"
