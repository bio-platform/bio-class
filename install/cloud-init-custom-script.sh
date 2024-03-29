#!/bin/bash

set -x

# Install all required software directly during VM cloud init (time consuming)
PATH=$PATH;PATH+=":/bin" ;PATH+=":/usr/bin";PATH+=":/usr/sbin";PATH+=":/usr/local/bin"; 
dirname=$(dirname $0)
cd "$dirname"
dirname=$(dirname pwd)
PATH+=":$dirname"
export PATH

CONF_DIR="$dirname"/../conf
LIB_DIR="$dirname"/../lib

# Set owner as root for debian ssh key to avoid login. Einfra account from metadata should be used to mount NFS storage.
# Uncomment here when finished development
chown root: /home/debian/.ssh/authorized_keys

# True to use deploy key or any other to download public repo
PRIVATE_REPO=""

# Set SSH Warning Message to Users
tmp_issuenet=$(cat /etc/issue.net)
echo -e "####################################################################
#                                                                  #
# Instance is during process of software instalation, please wait! #
#                                                                  #
# Login will be enabled after finished configuration.              #
#                                                                  #
####################################################################" > /etc/issue.net
sed -i 's/#Banner none$/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
systemctl restart sshd

# Backup repo
if [[ -d /home/debian/bio-class ]];then
  mv /home/debian/bio-class /home/debian/bio-class-backup
fi

#Script to download repo with bio-class Software
apt-get update ; apt-get upgrade; apt-get -y install apg curl wget; apt-get update;
# Alias ll for root account
sed -i 's/# alias ll=\x27ls \$LS_OPTIONS -l\x27/alias ll=\x27ls \$LS_OPTIONS -alF\x27/g' /root/.bashrc

apt-get -y install mc vim git dpkg-dev apt-transport-https ca-certificates dirmngr

if [[ "$PRIVATE_REPO" == "true" ]];then

  set +x

  # Using deploy key to access Github private repository
  # Private key for deploy key, NOT your personal private key!
  # This part is not necessary if repository public
  echo -e "-----BEGIN RSA PRIVATE KEY-----
...INSERT PRIVATE KEY AS DEPLOY KEY HERE...
-----END RSA PRIVATE KEY-----" > /root/.ssh/id_rsa

  # Public key for deploy keys
  # This part is not necessary if repository public
  echo -e "...INSERT PUBLIC KEY FOR DEPLOY KEY HERE..." > /root/.ssh/id_rsa.pub

  echo -e "# GitLab.com server
Host gitlab.com
RSAAuthentication yes
IdentityFile /root/.ssh/id_rsa
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null" > ~/.ssh/config

  set -x

  cd /root/
  chmod 700 .ssh/
  chmod 644 .ssh/authorized_keys
  chmod 644 .ssh/known_hosts
  chmod 644 .ssh/id_rsa.pub
  chmod 600 .ssh/id_rsa

  # Start SSH agent
  eval $(ssh-agent -s)
  ssh-add /root/.ssh/id_rsa
  # SSH Host Key Checking
  ssh-keyscan -H github.com >> /root/.ssh/known_hosts

  #test connection
  ssh -T git@github.com
  # test deploy key Fingerprint
  ssh-add -l -E md5

  # Clone repository
  cd /home/debian/;
  git clone git@github.com:bio-platform/bio-class.git 2>&1 > /home/debian/gitclone.txt

  # Delete deploy key
  rm -rf /root/.ssh/id_rsa*

  # Deletes all identities from the agent
  ssh-add -D

else
  # Clone public repo
  git clone https://github.com/bio-platform/bio-class.git 2>&1 > /home/debian/gitclone.txt

fi

# Cloned repository
cd /home/debian/;
if [[ ! -d /home/debian/bio-class ]];then
  if [[ -d /home/debian/bio-class-backup ]];then
    echo "ERROR to clone repository, using repository from image"
    mv /home/debian/bio-class-backup /home/debian/bio-class
  fi
else
  if [[ -d /home/debian/bio-class-backup ]];then
    rm -rf /home/debian/bio-class-backup
  fi
fi

# List if cloned successfully                
ls -la /home/debian/bio-class

# Change to repository
cd /home/debian/bio-class/install;

# Install software
chmod +x ./install_software.sh
./install_software.sh -m all 2>&1 | tee /home/debian/install_software_all.txt

# Remove SSH Warning Message to Users after finished Software isntalation
echo -e "${tmp_issuenet}" > /etc/issue.net
sed -i 's/Banner.*/#Banner none/g' /etc/ssh/sshd_config
systemctl restart sshd

exit 0
