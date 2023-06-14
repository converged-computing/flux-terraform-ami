#!/bin/bash

nodenames=$(flux exec -r all hostname)
echo $nodenames
IFS=' '
read -ra leader <<< $nodenames
# echo $leader

secret_token=${1}
[ $# -eq 0 ] && { echo "Usage: $0 argument, Provide k3s secret"; exit 1; }

flux run -N 3  --error ./k3s_starter.out --output ./k3s_starter.out sh ./k3s_starter.sh "${leader}" "${secret_token}"

echo "JOB COMPLETE"       