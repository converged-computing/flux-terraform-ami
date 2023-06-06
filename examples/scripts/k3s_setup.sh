#!/bin/bash

hosts=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=flux-selector" | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName)
NODELIST=""
for host in $hosts; do
   if [[ "$NODELIST" == "" ]]; then
      NODELIST=$host
   else
      NODELIST=$NODELIST,$host   
   fi
done

LEADER=($(echo $NODELIST | tr "," "\n"))

if [[ "$LEADER" == $(hostname) ]]; then
	curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" K3S_TOKEN="${k3s_token_name}" sh -
else
    #TODO Sleep until the K3S service at the masternode is active
    sleep 300
    curl -sfL https://get.k3s.io | K3S_URL=https://"$LEADER":6443 K3S_TOKEN="${k3s_token_name}" K3S_KUBECONFIG_MODE="644" sh -
fi  