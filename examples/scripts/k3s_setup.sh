#!/bin/bash

hosts=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=${selector_name}-selector" | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName)
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
   while :
      do
         curl --max-time 0.5 -k -o /dev/null https://"$LEADER":6443/livez
         res=$?
         if test "$res" != "0"; then
            echo "the curl command failed with: $res"
            sleep 5
         else
            echo "The K3S service is UP!"
            break
         fi
   done
   curl -sfL https://get.k3s.io | K3S_URL=https://"$LEADER":6443 K3S_TOKEN="${k3s_token_name}" K3S_KUBECONFIG_MODE="644" sh -
fi  