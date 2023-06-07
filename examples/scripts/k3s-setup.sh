#!/bin/bash

# Install AWS client
python3 -m pip install awscli

# Wait for the count to be up, total instances should be greater than or equal to desired.
while [[ $(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=${selector_name}-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName | wc -l) -lt ${desired_size} ]]
do
   echo "From User Data Script - Desired count not reached, sleeping."
   sleep 10
done

found_count=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=${selector_name}-selector" | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress | wc -l)
echo "Desired count $found_count is reached"

# Update the flux config files with our hosts - we need the ones from hostname
hosts=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:selector,Values=${selector_name}-selector" | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateDnsName)

# Hack them together into comma separated list
NODELIST=""
for host in $hosts; do
   if [[ "$NODELIST" == "" ]]; then
      NODELIST=$host
   else
      NODELIST=$NODELIST,$host   
   fi
done

# Replace in hostlist
sed -i 's/NODELIST/"'"$NODELIST"'"/g' /usr/local/etc/flux/system/conf.d/system.toml

# Delete flux manager line for now
gawk -i inplace '!/FLUXMANGER/' /usr/local/etc/flux/system/conf.d/system.toml

# Generate the flux resource file
flux R encode --hosts=$NODELIST > /usr/local/etc/flux/system/R

# Make the run directories in case not made yet
mkdir -p /run/flux
chown -R flux /run/flux

# See the README.md for commands how to set this manually without systemd
systemctl restart flux.service

## These are for installing K3S

LEADER=($(echo $NODELIST | tr "," "\n"))

if [[ "$LEADER" == $(hostname) ]]; then
	curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" K3S_TOKEN="${k3s_token_name}" sh -
else
    #Check if K3S API Server is running or not
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