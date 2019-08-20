#!/bin/bash
PATH=$PATH;PATH+=":/bin" ;PATH+=":/usr/bin";PATH+=":/usr/sbin";PATH+=":/usr/local/bin";
dirname=$(dirname $0)
cd "$dirname"
SCRIPTDIR=$(pwd)
dirname=$(dirname pwd)
PATH+=":$dirname"
export PATH

CONF_DIR="$dirname"/../conf
LIB_DIR="$dirname"/../lib

INDEVELOP="true"
MODE=
MODELIST="master"

# Include global Conf
. $CONF_DIR/.conf

#common_functions
. $LIB_DIR/common_functions

USER=$(whoami)
function_logger () {
    local tmp=$(echo "$1"| tr -s '\r\n' ';' |  sed '/^$/d')
    logger "`basename \"$0\"` $USER: $tmp"
    echo "$tmp"
}

# if without any parameters
if [[ $# -eq 0 ]]
  then

      echo "Install software for biology students.
Parameters:
-m Mode:
   master - Packer master instalation for building images using Packer
-v Verbose output.

"
exit 0
fi

# parse the arguments
while getopts ":m:v:" opt; do
  case $opt in
  m)
      if [[ $MODELIST =~ $OPTARG ]]; then
        MODE=$OPTARG
      else
        function_logger "Wrong parametr $OPTARG for mode parameter!"
        exit 1
      fi
      ;;
  v)
      verbose="verbose"
      _DEBUG="on"
      ;;
  \?)
      function_logger "Invalid option: $OPTARG"
      exit 1
      ;;
  esac
done









# Apt update + install directories
update_sources ;

# Script to install bio-class Software

# Enable wget, dpkg, add support for https apt sources, dirmngr (network certificate management service)
apt-get -y install mc vim git dpkg-dev apt-transport-https ca-certificates dirmngr

# Alias for ll
sed -i 's/# alias ll=\x27ls \$LS_OPTIONS -l\x27/alias ll=\x27ls \$LS_OPTIONS -alF\x27/g' /root/.bashrc
sed -i 's/#alias ll=\x27ls -l\x27/alias ll=\x27ls -laF\x27/g' /home/debian/.bashrc ;

# Edit sshd_config
set_sshd_config



# Install openstackclient
apt-get -y install python-pip
pip --version
pip install python-openstackclient
openstack --version

# Download Packer
wget  --no-verbose https://releases.hashicorp.com/packer/1.4.2/packer_1.4.2_linux_amd64.zip  -P /tmp/
cd /tmp/
unzip -q /tmp/packer_1.4.2_linux_amd64.zip -d /usr/local/bin
packer version






# Set ssh key for debain back to him
if [[ -z "$INDEVELOP" ]];then
  chown debian: /home/debian/.ssh/authorized_keys
fi


# "Finished Custom Script"
exit 0
