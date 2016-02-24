#!/bin/bash

. rpmfactory-base.sh

sudo yum install -y epel-release
sudo yum install -y python-crypto git python-pip python-devel gcc patch libffi-devel
sudo pip install -U ansible==1.9.2 virtualenv
ansible --version

cloudrepo="
[cloud]
name=CentOS-\$releasever - Cloud
baseurl=http://mirror.centos.org/centos/7/cloud/x86_64/openstack-liberty/
gpgcheck=0
enabled=1
"
echo "$cloudrepo" | sudo tee /etc/yum.repos.d/cloud.repo
sudo cp run-tox.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/run-tox.sh

# https://github.com/openstack-infra/system-config/blob/master/modules/openstack_project/manifests/thick_slave.pp
sudo yum install -y mariadb-devel postgresql-devel libjpeg-devel
sudo yum install -y gcc-c++ zeromq-devel libxslt-devel sqlite-devel
sudo yum install -y libvirt-devel openldap-devel libxml2-devel
sudo yum install -y liberasurecode-devel openssl-devel

# install khaleesi
git clone https://github.com/redhat-openstack/khaleesi.git
git clone https://github.com/redhat-openstack/khaleesi-settings.git

pushd khaleesi/tools/ksgen
sudo python setup.py install
popd

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync

# Remove epel and cloud repo
sudo yum remove -y epel-release
sudo rm /etc/yum.repos.d/cloud.repo

echo "Setup finished. Creating snapshot now, this will take a few minutes"