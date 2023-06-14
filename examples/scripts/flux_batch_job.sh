#!/bin/bash

# Read all the hostname the job is running
nodenames_string=$(flux exec -r all hostname)
echo $nodenames_string
# separate the names into an array
IFS=' '
read -ra nodenames_array <<< $nodenames_string
leader=${nodenames_array[0]}
echo $leader

secret_token=${1}
[ $# -eq 0 ] && { echo "Usage: $0 argument, Provide k3s secret"; exit 1; }

flux submit -N 3 --wait --error ./k3s_starter.out --output ./k3s_starter.out sh ./k3s_starter.sh "${leader}" "${secret_token}"

echo "JOB COMPLETE"       