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

BIOUSER=$(curl -s  http://169.254.169.254/openstack/2016-06-30/meta_data.json 2>/dev/null | python -m json.tool | egrep -i Bioclass_user |cut -f 2 -d ':' | tr -d ' ' | tr -d '"' | tr '[:upper:]' '[:lower:]')
if [[ -z "$BIOUSER" ]]; then
  echo "Empty Bioclass_user from METADATA, exiting!"
  exit 1
fi

echo "Install patch if needed"

# Patch

# Trimmomatic - executable .jar file
if [[ ! -f /usr/bin/trimmomatic ]];then
  cp ${SCRIPTDIR}/trimmomatic /usr/bin
  chown root: /usr/bin/trimmomatic
  chmod 755 /usr/bin/trimmomatic
fi

# Fail2ban
if [[ ! -f /etc/fail2ban/jail.local ]] || [[ ! -f /etc/fail2ban/filter.d/nginx-rstudio.conf ]] || [[ ! -f /etc/fail2ban/filter.d/repeat-offender.conf ]] || [[ ! -f /etc/fail2ban/filter.d/repeat-offender-found.conf ]];then
  apt-get -y install iptables fail2ban
  cp ${CONF_DIR}/jail.local /etc/fail2ban
  cp ${CONF_DIR}/nginx-rstudio.conf /etc/fail2ban/filter.d
  cp ${CONF_DIR}/repeat-offender.conf /etc/fail2ban/filter.d
  cp ${CONF_DIR}/repeat-offender-found.conf /etc/fail2ban/filter.d
  for file in /etc/fail2ban/filter.d/nginx-rstudio.conf /etc/fail2ban/jail.local /etc/fail2ban/filter.d/repeat-offender.conf /etc/fail2ban/filter.d/repeat-offender-found.conf ; do \
  chown root: $file ; \
  chmod 644 $file ; done
  service fail2ban restart
fi

# Updates
if [[ ! -f /etc/cron.d/updates ]];then
  echo  -e "0 0 1-7 * * root [ \$(date +\%u) -eq 6 ] && rm -rf /home/debian/updates.txt.old && mv /home/debian/updates.txt /home/debian/updates.txt.old" | sudo tee -a /etc/cron.d/updates
  echo -e "5,15,25 1 1-7 * * ${BIOUSER} [ \$(date +\%u) -eq 6 ] && cd /home/debian/bio-class/install && /usr/bin/flock -w 10 /var/lock/bio-class/updates ./install_software_check.sh -m updateREPO 2>&1 | sudo tee -a /home/debian/updates.txt" | sudo tee -a /etc/cron.d/updates
  echo -e "40 1 1-7 * * ${BIOUSER} [ \$(date +\%u) -eq 6 ] && cd /home/debian/bio-class/install && /usr/bin/flock -w 10 /var/lock/bio-class/updates ./install_software_check.sh -m updateOS 2>&1 | sudo tee -a /home/debian/updates.txt" | sudo tee -a /etc/cron.d/updates
  echo -e "0 5 1-7 * * ${BIOUSER} [ \$(date +\%u) -eq 6 ] && cd /home/debian/bio-class/install && /usr/bin/flock -w 10 /var/lock/bio-class/updates ./install_software_check.sh -m updateBIOSW 2>&1 | sudo tee -a /home/debian/updates.txt" | sudo tee -a /etc/cron.d/updates
fi

# Fastx GD
apt-get install -y libgd-perl gnuplot
if [[ ! -f /usr/local/share/perl/5.24.1/GD/Graph.pm ]];then
  export PERL_MM_USE_DEFAULT=1
  perl -MCPAN -e 'install "YAML"'
  perl -MCPAN -e 'install "GD"'
  perl -MCPAN -e 'install "GD::Graph::bars"'
  perl -MCPAN -e 'install "PerlIO::gzip"'
fi

# Patch
echo "Install patch has finished"

# Print user to check in log
echo "BIOUSER: $BIOUSER"

exit 0
