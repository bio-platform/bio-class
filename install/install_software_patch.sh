#!/bin/bash
# Install patch if difference betweenprepared image/upstream repository versions
PATH=$PATH;PATH+=":/bin" ;PATH+=":/usr/bin";PATH+=":/usr/sbin";PATH+=":/usr/local/bin"; 
dirname=$(dirname $0)
cd "$dirname"
SCRIPTDIR=$(pwd)
dirname=$(dirname pwd)
PATH+=":$dirname"
export PATH

CONF_DIR="$dirname"/../conf
LIB_DIR="$dirname"/../lib

echo "Install patch if needed"

# Patch
chown root: /home/debian/.ssh/authorized_keys

# Nginx Welcome Page
  cp ${CONF_DIR}/index.nginx-debian.html /var/www/html/
  if [[ -f /var/www/html/index.nginx-debian.html ]];then
    chown root: /var/www/html/index.nginx-debian.html                                                                                                                                                chmod 644 /var/www/html/index.nginx-debian.html                                                                                                                                                fi

# Patch

exit 0
