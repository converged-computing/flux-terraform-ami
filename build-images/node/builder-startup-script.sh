#!/bin/bash 

# This was originally for login nodes
cat << "CONFIG_HOSTBASED_AUTH" > /tmp/03-hostbased-auth.sh
#!/bin/bash

cd /etc/ssh
 
chmod u+s /usr/libexec/openssh/ssh-keysign
 
sed -i 's/#   HostbasedAuthentication no/    HostbasedAuthentication yes\n    EnableSSHkeysign yes/g' /etc/ssh/ssh_config
CONFIG_HOSTBASED_AUTH

sudo mkdir -p /etc/flux/login/conf.d
sudo mv /tmp/03-hostbased-auth.sh /etc/flux/login/conf.d/03-hostbased-auth.sh


# This was originally for the manager
sudo chown flux:flux /usr/local/etc/flux

sudo mkdir -p /usr/local/etc/flux/imp/conf.d
cat << IMP_TOML > /tmp/imp.toml
# Only allow access to the IMP exec method by the 'flux' user.
# Only allow the installed version of flux-shell(1) to be executed.
[exec]
allowed-users = [ "flux" ]
allowed-shells = [ "/usr/local/libexec/flux/flux-shell" ]
IMP_TOML

sudo mv /tmp/imp.toml /usr/local/etc/flux/imp/conf.d/imp.toml

sudo -u flux mkdir -p /usr/local/etc/flux/system/conf.d
cat << SYSTEM_TOML > /tmp/system.toml
# Flux needs to know the path to the IMP executable
[exec]
imp = "/usr/local/libexec/flux/flux-imp"

# Allow users other than the instance owner (guests) to connect to Flux
# Optionally, root may be given "owner privileges" for convenience
[access]
allow-guest-user = true
allow-root-owner = true

# Point to shared network certificate generated flux-keygen(1).
# Define the network endpoints for Flux's tree based overlay network
# and inform Flux of the hostnames that will start flux-broker(1).
[bootstrap]
curve_cert = "/usr/local/etc/flux/system/curve.cert"

default_port = 8050
default_bind = "tcp://eth0:%p"
default_connect = "tcp://%h:%p"

# TODO this needs to somehow be replaced on startup with actual hosts
hosts = [{ host = NODELIST },]

# Speed up detection of crashed network peers (system default is around 20m)
[tbon]
tcp_user_timeout = "2m"

# Point to resource definition generated with flux-R(1).
# Uncomment to exclude nodes (e.g. mgmt, login), from eligibility to run jobs.
[resource]
path = "/usr/local/etc/flux/system/R"
exclude = "FLUXMANGER"

# Remove inactive jobs from the KVS after one week.
[job-manager]
inactive-age-limit = "7d"
SYSTEM_TOML

sudo mv /tmp/system.toml /usr/local/etc/flux/system/conf.d/system.toml
sudo -u flux /usr/local/bin/flux keygen /usr/local/etc/flux/system/curve.cert

sudo chown -R flux:flux /usr/local/etc/flux

sudo chown root:root /usr/local/etc/flux/rc1
sudo chown -R root:root /usr/local/etc/flux/rc1.d
sudo chown root:root /usr/local/etc/flux/rc3
sudo chown -R root:root /usr/local/etc/flux/rc3.d

sudo chown -R root:root /usr/local/etc/flux/security/conf.d

sudo chown -R root:root /usr/local/etc/flux/imp/conf.d
sudo chmod go-wx /usr/local/etc/flux/imp/conf.d
sudo chmod u+r,u-wx,go-rwx /usr/local/etc/flux/imp/conf.d/imp.toml
sudo chmod u+s /usr/local/libexec/flux/flux-imp

sudo mkdir -p /etc/flux/manager/conf.d

cat << "CONFIG_FLUX_SYSTEM" > /tmp/01-system.sh
#!/bin/bash

sed -i "s/FLUXMANGER/$(hostname -s)/g" /usr/local/etc/flux/system/conf.d/system.toml

CORES=$(($(hwloc-ls -p | grep -i core | wc -l)-1))
/usr/local/bin/flux R encode --ranks=0 --hosts=$(hostname -s) --cores=0-$CORES --property=manager | tee /usr/local/etc/flux/system/R > /dev/null
chown flux:flux /usr/local/etc/flux/system/R

cp /usr/share/flux-core/etc/flux.service /usr/lib/systemd/system
CONFIG_FLUX_SYSTEM

sudo mv /tmp/01-system.sh /etc/flux/manager/conf.d/01-system.sh

cat << "CONFIG_FLUX_RESOURCES" > /tmp/02-resources.sh
#!/usr/bin/env  bash
mkdir -p /usr/local/etc/flux/system
chown flux:flux /usr/local/etc/flux/system/R
CONFIG_FLUX_RESOURCES

sudo mv /tmp/02-resources.sh /etc/flux/manager/conf.d/02-resources.sh

cat << "CONFIG_FLUX_NFS" > /tmp/03-flux-nfs.sh
#!/bin/bash

sed -i "/^#Domain/s/^#//;/Domain = /s/=.*/= $(hostname -d)/" /etc/idmapd.conf

systemctl restart nfs-server
CONFIG_FLUX_NFS

sudo mv /tmp/03-flux-nfs.sh /etc/flux/manager/conf.d/03-flux-nfs.sh

cat << "CONFIG_HOSTBASED_AUTH" > /tmp/05-hostbased-auth.sh
#!/bin/bash

cd /etc/ssh
 
chmod u+s /usr/libexec/openssh/ssh-keysign
 
sed -i 's/#   HostbasedAuthentication no/    HostbasedAuthentication yes\n    EnableSSHkeysign yes/g' /etc/ssh/ssh_config
CONFIG_HOSTBASED_AUTH
sudo mv /tmp/05-hostbased-auth.sh /etc/flux/manager/conf.d/05-hostbased-auth.sh

sudo /usr/sbin/create-munge-key

# This assumes /etc/exports does not exist
echo "/usr/local/etc/flux/imp *(rw,no_subtree_check,no_root_squash)" >> /tmp/exports
echo "/usr/local/etc/flux/security *(rw,no_subtree_check,no_root_squash)" >> /tmp/exports
echo "/usr/local/etc/flux/system *(rw,no_subtree_check,no_root_squash)" >> /tmp/exports
echo "/etc/munge *(rw,no_subtree_check,no_root_squash)" >> /tmp/exports

sudo mv /tmp/exports /etc/exports
sudo systemctl enable nfs-server

# Just in case it isn't made yet...
sudo mkdir -p /etc/flux/compute/conf.d

cat << "RUN_BOOT_SCRIPT" > /tmp/99-boot-script.sh
#!/bin/bash

echo "Hello I am booting."

RUN_BOOT_SCRIPT
sudo mv /tmp/99-boot-script.sh /etc/flux/compute/conf.d/99-boot-script.sh
