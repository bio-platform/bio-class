#!/bin/bash
# Script used during packer image procedure
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
#chown root: /home/debian/.ssh/authorized_keys

# True to use deploy key or any other to download public repo
PRIVATE_REPO=""

# Disable login using password
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config ;
/etc/init.d/ssh reload

# Set SSH Warning Message to Users
tmp_issuenet=$(sudo cat /etc/issue.net)
sudo sh -c "echo '####################################################################
#                                                                  #
# Instance is during process of software instalation, please wait! #
#                                                                  #
# Login will be enabled after finished configuration.              #
#                                                                  #
####################################################################' > /etc/issue.net"
sudo sed -i 's/#Banner none$/Banner \/etc\/issue.net/g' /etc/ssh/sshd_config
sudo systemctl restart sshd


#Script to download repo with bio-class Software
sudo apt-get update ; sudo apt-get upgrade; sudo apt-get -y install apg curl wget; sudo apt-get update;
# Alias ll for root account
sudo sed -i 's/# alias ll=\x27ls \$LS_OPTIONS -l\x27/alias ll=\x27ls \$LS_OPTIONS -alF\x27/g' /root/.bashrc

sudo apt-get -y install mc vim git dpkg-dev apt-transport-https ca-certificates dirmngr

cd /home/debian/;

if [[ "$PRIVATE_REPO" == "true" ]];then
  # Private key for deploy keys
  #...INSERT PRIVATE KEY AS DEPLOY KEY HERE...
  echo -e "-----BEGIN RSA PRIVATE KEY-----
...INSERT PRIVATE KEY AS DEPLOY KEY HERE...
-----END RSA PRIVATE KEY-----" > ~/.ssh/id_rsa
  #...INSERT PRIVATE KEY AS DEPLOY KEY HERE...

  # Public key for deploy keys
  echo -e "...INSERT PUBLIC KEY FOR DEPLOY KEY HERE..." > ~/.ssh/id_rsa.pub

  echo -e "# GitLab.com server
Host gitlab.com
RSAAuthentication yes
IdentityFile /root/.ssh/id_rsa
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null" > ~/.ssh/config

  cd ~ ; chmod 700 .ssh/ ; chmod 644 .ssh/authorized_keys ; touch .ssh/known_hosts ; chmod 644 .ssh/known_hosts ; chmod 644 .ssh/id_rsa.pub ;chmod 600 .ssh/id_rsa;

  # Start SSH agent
  eval $(ssh-agent -s)
  ssh-add ~/.ssh/id_rsa
  # SSH Host Key Checking
  ssh-keyscan -H github.com >> ~/.ssh/known_hosts



  #test connection
  ssh -T git@github.com
  # test deploy key Fingerprint
  ssh-add -l -E md5

  # Clone repository
  cd /home/debian/;
  git clone git@github.com:bio-platform/bio-class.git 2>&1 > /home/debian/gitclone.txt

  # Delete deploy key
  rm -rf /home/debian/.ssh/id_rsa*

  # Delete all identities from the agent
  ssh-add -D
else
  # Clone public repo
  git clone https://github.com/bio-platform/bio-class.git 2>&1 > /home/debian/gitclone.txt

fi


# List if cloned successfully                
ls -la /home/debian/bio-class

# Change to repository
cd /home/debian/bio-class/install;

# Install software
chmod +x ./install_software.sh
sudo ./install_software.sh -m base 2>&1 | sudo tee /home/debian/install_software_base.txt
#sudo sh -c "echo 'aaa' > /home/debian/install_software_base.txt"
#sudo sh -c "echo 'bbb' > /home/debian/installed_files.txt"
#sudo sh -c "echo 'ccc' > /home/debian/path.txt"

echo "# Remove SSH Warning Message to Users after finished Software instalation"
sudo sh -c "echo ${tmp_issuenet} > /etc/issue.net"
sudo sed -i 's/Banner.*/#Banner none/g' /etc/ssh/sshd_config
sudo systemctl restart sshd


exit 0
