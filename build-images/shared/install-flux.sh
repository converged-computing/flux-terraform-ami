#!/bin/bash 

# Copyright 2022 Google LLC
# Modified by HPCIC DevTools 2023

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# TODO install aws fuse

sudo dnf update -y
sudo dnf clean all

sudo dnf group install -y "Development Tools"

sudo dnf config-manager --set-enabled powertools
sudo dnf install -y epel-release

sudo dnf install -y \
    munge \
    munge-devel \
    hwloc \
    hwloc-devel \
    lua \
    lua-devel \
    lua-posix \
    czmq-devel \
    jansson-devel \
    lz4-devel \
    sqlite-devel \
    ncurses-devel \
    libarchive-devel \
    libxml2-devel \
    yaml-cpp-devel \
    boost-devel \
    libedit-devel \
    nfs-utils \
    python36-devel \
    python3-cffi \
    python3-yaml \
    python3-jsonschema \
    python3-sphinx \
    python3-docutils \
    aspell \
    aspell-en \
    valgrind-devel \
    libevent-devel \
    openmpi.x86_64 \
    openmpi-devel.x86_64 \
    fuse \
    pmix \
    jq

# Install pmix
git clone https://github.com/openpmix/openpmix.git && \
git clone https://github.com/openpmix/prrte.git && \
    ls -l && \
    set -x && \
    cd openpmix && \
    git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93 && \
    ./autogen.pl && \
    ./configure --prefix=/usr --disable-static && sudo make -j 4 install && \
    sudo ldconfig && \
    cd .. && \
    cd prrte && \
    git checkout 477894f4720d822b15cab56eee7665107832921c && \
    ./autogen.pl && \
    python ./configure --prefix=/usr && sudo make -j 4 install && \
    cd ../.. && \
    rm -rf prrte

# If GPUs are wanted, this will be available to install the driver
curl -L https://developer.download.nvidia.com/compute/cuda/11.7.1/local_installers/cuda-repo-rhel8-11-7-local-11.7.1_515.65.01-1.x86_64.rpm --output /var/tmp/cuda-repo-rhel8-11-7-local-11.7.1_515.65.01-1.x86_64.rpm
curl https://raw.githubusercontent.com/GoogleCloudPlatform/compute-gpu-installation/main/linux/install_gpu_driver.py --output /var/tmp/install_gpu_driver.py

# Apptainer / Singularity
APPTAINER_ASSETS=$(curl -s https://api.github.com/repos/apptainer/apptainer/releases/latest | jq '.[] | match(".*assets$"; "g") | .string' 2>/dev/null | tr -d '"')
APPTAINER_RPM=$(curl -s ${APPTAINER_ASSETS} | jq '.[] | .browser_download_url' | egrep .*apptainer-[[:digit:]].*x86_64 | tr -d '"')
sudo dnf install -y ${APPTAINER_RPM}

# Flux Assets
sudo useradd -M -r -s /bin/false -c "flux-framework identity" flux
sudo chown -R $USER /usr/share
cd /usr/share

git clone -b v0.49.0 https://github.com/flux-framework/flux-core.git
git clone -b v0.27.0 https://github.com/flux-framework/flux-sched.git
git clone -b v0.8.0 https://github.com/flux-framework/flux-security.git
git clone -b v0.3.0 https://github.com/flux-framework/flux-pmix.git

cd /usr/share/flux-security

./autogen.sh
./configure --prefix=/usr/local

make
sudo make install

cd /usr/share/flux-core

./autogen.sh

PKG_CONFIG_PATH=$(pkg-config --variable pc_path pkg-config)
PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
PKG_CONFIG_PATH=${PKG_CONFIG_PATH} ./configure --prefix=/usr/local --with-flux-security

make -j 8
sudo make install

cd /usr/share/flux-sched

./autogen.sh
./configure --prefix=/usr/local

make
sudo make install

cd /usr/share/flux-pmix

./autogen.sh
./configure --prefix=/usr/local

make
sudo make install

sudo chmod u+s /usr/local/libexec/flux/flux-imp
sudo cp /usr/share/flux-core/etc/flux.service /usr/lib/systemd/system
sudo mkdir -p /etc/flux/compute/conf.d

# TODO add startup scripts here to configure cluster connection
# And binds to shared filesystems (e.g., with aws fuse or similar)

cat << "COMPUTE_FIRST_BOOT" > /tmp/first-boot.sh
#!/bin/bash

for cs in $(ls /etc/flux/compute/conf.d/*.sh | sort -n); do . $cs; done

systemctl enable --now flux
COMPUTE_FIRST_BOOT

sudo mv /tmp/first-boot.sh /etc/flux/compute/first-boot.sh
sudo chmod u+x,go-rwx /etc/flux/compute/first-boot.sh

cat << "FIRST_BOOT_UNIT" > /tmp/flux-config-compute.service
[Unit]
Wants=systemd-hostnamed
After=systemd-hostnamed
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/var/lib/flux-compute-configured

[Service]
Type=oneshot
ExecStartPre=/bin/bash -c 'while [[ "$(hostname)" =~ "packer" ]]; do sleep 1; done'
ExecStart=/etc/flux/compute/first-boot.sh
ExecStartPost=/usr/bin/touch /var/lib/flux-compute-configured
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FIRST_BOOT_UNIT

sudo mv /tmp/flux-config-compute.service /etc/systemd/system/flux-config-compute.service
sudo systemctl enable flux-config-compute.service
