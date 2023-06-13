#!/bin/bash

# Get the ID of the submitted job
jobid=$(flux job last)
nodenames=$(flux job info --original ${jobid} R | jq -r .execution.nodelist[0])
leader=($(echo $nodenames | tr "," "\n"))

# leader=${1}
secret_token=${1}

FILE_K3S_AGENT_ENV=/etc/systemd/system/k3s-agent.service.env
FILE_K3S_ENV=/etc/systemd/system/k3s.service.env
#sudo rm -rf ${FILE_K3S_ENV}
#sudo rm -rf ${FILE_K3S_AGENT_ENV}

if [[ "$leader" == $(hostname) ]]; then
    echo "I'm the leader, ${leader}"	
    sudo touch ${FILE_K3S_ENV}
    sudo chmod 0600 ${FILE_K3S_ENV}
    echo K3S_TOKEN=${secret_token} | sudo tee -a ${FILE_K3S_ENV}
    sudo systemctl start k3s.service
    sudo systemctl status k3s.service	

else
    #Check if K3S API Server is running or not
    echo "I'm a worker, ${hostname}"
    while :
    do
        curl --max-time 0.5 -k -s /dev/null https://"$leader":6443/livez
        res=$?
        if test "$res" != "0"; then
            echo "the curl command failed with: $res"
	    echo "Checking again if K3S API is active"
            sleep 5
        else
            echo "The K3S service is UP!"
            break
        fi
    done
    
    sudo touch ${FILE_K3S_AGENT_ENV}
    sudo chmod 0600 ${FILE_K3S_AGENT_ENV}
    echo K3S_URL="https://$leader:6443" | sudo tee -a ${FILE_K3S_AGENT_ENV}
    echo K3S_TOKEN=${secret_token} | sudo tee -a ${FILE_K3S_AGENT_ENV}
    sudo systemctl start k3s-agent.service
    sudo systemctl status k3s-agent.service
fi

sleep 60
if [[ "$leader" == $(hostname) ]]; then
    sudo k3s kubectl get nodes
    sudo k3s kubectl get pods
    sudo k3s kubectl create ns yelb
    sudo k3s kubectl apply -f https://raw.githubusercontent.com/lamw/vmware-k8s-app-demo/master/yelb.yaml    
    sudo k3s kubectl -n yelb get pods -o wide
    sleep 60
    sudo k3s kubectl -n yelb get pods -o wide	
    sudo k3s kubectl -n yelb get svc
    sudo k3s kubectl delete -f https://raw.githubusercontent.com/lamw/vmware-k8s-app-demo/master/yelb.yaml    
fi

sleep 10
sudo k3s kubectl get nodes -o wide
echo "Deactivating Services"
if [[ "$leader" == $(hostname) ]]; then
    sudo systemctl stop k3s.service
else
    sudo systemctl stop k3s-agent.service
fi
    
echo "Removing configs"
sleep 10
sudo rm -rf /etc/rancher/*
sudo rm -rf /var/lib/rancher/*
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /var/lib/kdump
sudo rm -rf /etc/systemd/system/k3s.service.env
sudo rm -rf /etc/systemd/system/k3s-agent.service.env
echo "Clean-up DONE"

echo "Have a good day!"