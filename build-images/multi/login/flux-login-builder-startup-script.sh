#!/bin/bash 

# This is only for the login node(s)
cat << "CONFIG_HOSTBASED_AUTH" > /tmp/03-hostbased-auth.sh
#!/bin/bash

cd /etc/ssh
 
chmod u+s /usr/libexec/openssh/ssh-keysign
 
sed -i 's/#   HostbasedAuthentication no/    HostbasedAuthentication yes\n    EnableSSHkeysign yes/g' /etc/ssh/ssh_config
CONFIG_HOSTBASED_AUTH

sudo mkdir -p /etc/flux/login/conf.d
sudo mv /tmp/03-hostbased-auth.sh /etc/flux/login/conf.d/03-hostbased-auth.sh
