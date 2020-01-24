#!/bin/bash
set -e

export HOME=/root

# Hack to make sure we don't start installing packages until the filesystem is available.
echo "waiting 180 seconds for cloud-init to update /etc/apt/sources.list"
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'

# Install packages.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    git curl wget \
    conntrack socat \
    inotify-tools \
    unzip \
    make golang-go \
    jq vim nano emacs joe \
    bash-completion

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt-get -y install \
  docker-ce \
  docker-ce-cli \
  containerd.io

# Make sure SSH does not break.
apt-get -y remove sshguard

# Disable auto updates as they break things.
systemd-run --property="After=apt-daily.service apt-daily-upgrade.service" --wait /bin/true
systemctl mask apt-daily.service apt-daily-upgrade.service

# Improve the startup sequence
cp /tmp/google-startup-scripts.service /etc/systemd/system/multi-user.target.wants/google-startup-scripts.service

# Start Docker, in case we need to pre-pull images in derivatives of this image.
systemctl daemon-reload
systemctl enable docker
systemctl start docker

VERSION=1.5.0
OS=linux
ARCH=amd64
curl -fsSL "https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v${VERSION}/docker-credential-gcr_${OS}_${ARCH}-${VERSION}.tar.gz" \
  | tar xz --to-stdout ./docker-credential-gcr \
  > /usr/bin/docker-credential-gcr && chmod +x /usr/bin/docker-credential-gcr

docker-credential-gcr configure-docker

# Install shipyard
curl https://shipyard.run/install | bash

# Run the blueprint
shipyard run github.com/hashicorp-demoapp/infrastructure//blueprint

# Replace with a nice check at some point
sleep 60

# Pause the application
shipyard pause

# Install Tools

## Install Vault
wget https://releases.hashicorp.com/vault/1.3.1/vault_1.3.1_linux_amd64.zip
unzip vault_1.3.1_linux_amd64.zip
mv vault /usr/bin

## Install Consul
wget https://releases.hashicorp.com/consul/1.6.2/consul_1.6.2_linux_amd64.zip
unzip consul_1.6.2_linux_amd64.zip
mv consul /usr/bin

## Install Kubectl 
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/bin