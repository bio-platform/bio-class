#!/bin/bash
PATH=$PATH;PATH+=":/bin" ;PATH+=":/usr/bin";PATH+=":/usr/sbin";PATH+=":/usr/local/bin"; 
dirname=$(dirname $0)
cd "$dirname"
SCRIPTDIR=$(pwd)
dirname=$(dirname pwd)
PATH+=":$dirname"
export PATH

CONF_DIR="$dirname"/conf

# Include global Conf
. $CONF_DIR/.conf

# Used to create/renew cert
MODE=
MODELIST="http https localcrt status backup restore renew"

# Username from home directory
USER=$(pwd | sed -rn "s/[/]*home[/]*([a-z0-9\-\_]+)[/]*.*/\1/p")
FORCE=

# User executing this script
SCRIPT_USER=$(whoami)

function_logger () {
    local tmp=$(echo "$1"| tr -s '\r\n' ';' |  sed '/^$/d')
    logger "`basename \"$0\"` $USER: $tmp"
    echo "$tmp"
}

# If without any parameters
if [[ $# -eq 0 ]]
  then

      echo "Create/renew certificate for HTTPS.
Parameters:
-m Mode:
   https - Create certificate for HTTPS using Let's Encrypt.
   renew - Renew existing Let's Encrypt certificate.
   http - Revert configuration back from Let's Encrypt to http only (Unsecure).
   localcrt - In case of changing Floating IP, set up local certificate to use HTTPS instead of unsecured HTTP. Please note that server's certificate in this case is not trusted in browsers and you definitely need to manually allow Continue to <Floating IP> (Not secured) to show page. (For Experienced Users Only)
   backup - Backup Let's Encrypt certificate to NFS storage.
   restore - Restore Let's Encrypt certificate backup from NFS storage to local disc.
-f Force 
-v Verbose output.

Example how to mount NFS storage at first login using your META password:
./startHTTPS.sh -m https
"
exit 0
fi

# Parse the arguments
while getopts ":m:v:f:" opt; do
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
  f)
       FORCE="$OPTARG"
       ;;

  \?)
      function_logger "Invalid option: $OPTARG"
      exit 1
      ;;
  esac
done

# Reset
Color_Off='\e[0m'       # Text Reset

# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

function DEBUG()
{
 [ "$_DEBUG" == "on" ] && [ ! "$SCRIPT_USER" == "root" ] && echo -e "[${Yellow}DEBUG${Color_Off}] $@"
 [ "$_DEBUG" == "on" ] && [ "$SCRIPT_USER" == "root" ] && echo -e "[DEBUG] $@"
}
function ERROR()
{
  [ ! "$SCRIPT_USER" == "root" ] && echo -e "[${Red}ERROR${Color_Off}] $@"
  [ "$SCRIPT_USER" == "root" ] && echo -e "[ERROR] $@"
}
function OK()
{
  [ ! "$SCRIPT_USER" == "root" ] && echo -e "[${Green}OK${Color_Off}]    $@"
  [ "$SCRIPT_USER" == "root" ] && echo -e "[OK]    $@"
}
function INFO()
{
  [ ! "$SCRIPT_USER" == "root" ] && echo -e "[${Yellow}INFO${Color_Off}]  $@"
  [ "$SCRIPT_USER" == "root" ] && echo -e "[INFO]  $@"
}
function WARN()
{
  [ ! "$SCRIPT_USER" == "root" ] && echo -e "[${Cyan}WARN${Color_Off}]  $@"
  [ "$SCRIPT_USER" == "root" ] && echo -e "[WARN]  $@"
}

DEBUG "USER: $USER"
if [[ -z "$USER" ]];then
  ERROR "User not defined, unable to continue!"
  exit 1
fi

public_ipv4=$(curl -s http://169.254.169.254/2009-04-04/meta-data/public-ipv4 2>/dev/null | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
if [[ -n "$public_ipv4" ]];then
  public_ipv4_2text=$(echo "$public_ipv4" | tr '.' '-')
  public_ipv4_name=$(nslookup "$public_ipv4" | grep name | sed -rn "s/.*name = (.*)[.]+$/\1/p" | sed "s/\.$//g")
fi

INFO "Public IPv4: $public_ipv4"
DEBUG "public_ipv4_2text: $public_ipv4_2text"
INFO "Public IPv4 Domain Name: $public_ipv4_name"

# Check if backup directory available
if [[ -z "$NFS_HOME_PERSISTENT" ]] && ( [[ "$MODE" == "https" ]] || [[ "$MODE" == "restore" ]]);then
  ERROR "NFS directory for certificate backup is not defined, please verify ./conf/.conf file with configuration!"
  exit 1
fi
if [[ -z "$NFS_STORAGE_BACKUP_HTTPS_DIR" ]] && ( [[ "$MODE" == "https" ]] || [[ "$MODE" == "restore" ]]);then
  ERROR "NFS backup directory name for certificate backup is not defined, please verify ./conf/.conf file with configuration!"
  exit 1
fi
if ( [[ "$MODE" == "https" ]] || [[ "$MODE" == "restore" ]]);then
  if [[ -d "${NFS_HOME_PERSISTENT}" ]];then
    if [[ -z `find "${NFS_HOME_PERSISTENT}" -maxdepth 1 -type d -path "${NFS_HOME_PERSISTENT}/${USER}"` ]];then
      INFO "Attempt to create direcory ${NFS_HOME_PERSISTENT}/${USER}"
      mkdir -p "${NFS_HOME_PERSISTENT}/${USER}"
      if [[ $? -ne 0 ]];then
        ERROR "Unable to create directory ${NFS_HOME_PERSISTENT}/${USER}, check if NFS nounted correctly!"
      fi
      INFO "Attempt to set group ${NFS_HOME_PERSISTENT_USER_GROUP_PERM} permissions on direcory ${NFS_HOME_PERSISTENT}/${USER}"
      chown ${USER}:${NFS_HOME_PERSISTENT_USER_GROUP_PERM} ${NFS_HOME_PERSISTENT}/${USER}
      if [[ $? -ne 0 ]];then
        ERROR "Unable to set permission for ${NFS_HOME_PERSISTENT_USER_GROUP_PERM} on directory ${NFS_HOME_PERSISTENT}/${USER}, check if NFS nounted correctly!"
      fi
    fi
  else
    ERROR "Unable to find NFS directory ${NFS_HOME_PERSISTENT}, check it please!"
    INFO "Consider to execute command startNFS before generating certificate."
    exit 1
  fi
fi

if ( [[ "$MODE" == "https" ]] || [[ "$MODE" == "restore" ]]);then
  if [[ -z `find "${NFS_HOME_PERSISTENT}" -maxdepth 1 -type d -path "${NFS_HOME_PERSISTENT}/${USER}"` ]];then
    ERROR "Unable to find NFS backup directory ${NFS_HOME_PERSISTENT}/${USER}, check it please!"
    INFO "Consider to execute command startNFS before generating certificate."
    exit 1
  else
    DEBUG "Crete HTTPS backup directory on NFS"
    cd "${NFS_HOME_PERSISTENT}/${USER}" && mkdir -p "./${NFS_STORAGE_BACKUP_HTTPS_DIR}" ; chmod 700 "./${NFS_STORAGE_BACKUP_HTTPS_DIR}"
    cd "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}"
    TMPFILE=`timeout 60 mktemp .placeholder-XXXXXX`
    if [[ $? -ne 0 ]];then
      ERROR "Unable to create temporary file on NFS"
      exit 1
    fi
    rm $TMPFILE
    if [[ $? -ne 0 ]];then
      ERROR "Temporary file created, but NOT deleted"
      exit 1
    fi
    cd $SCRIPTDIR
  fi
fi

# Email used to register certificate for
BIOUSER_EMAIL=$(curl -s  http://169.254.169.254/openstack/2016-06-30/meta_data.json 2>/dev/null | python -m json.tool | egrep -i Bioclass_email |cut -f 2 -d ':' | tr -d ' ' | tr -d '"' |sed 's/,$//g'| tr '[:upper:]' '[:lower:]')
if [[ "$MODE" == "https" ]];then
  if [[ -z "$BIOUSER_EMAIL" ]];then
    ERROR "Empty email for certificate procedure, exiting!"
    exit 1
  else
    INFO "BIOUSER_EMAIL: $BIOUSER_EMAIL"
  fi
fi

# Get current certificate state
checkstate() {
  # Check current state
  if [[ -n "$public_ipv4" ]] && [[ -n "$public_ipv4_2text" ]] && [[ -n "$BIOUSER_EMAIL" ]]; then
    chain_exists=$(sudo certbot certificates 2>&1 | egrep "Certificate Path" | egrep "$public_ipv4_2text")
    key_exists=$(sudo certbot certificates 2>&1| egrep "Private Key Path" | egrep "$public_ipv4_2text")
    cert_path=$(sudo find /etc/letsencrypt/live/ -name cert.pem 2>/dev/null | head -n 1)
    key_path=$(sudo find /etc/letsencrypt/live/ -name privkey.pem 2>/dev/null | head -n 1)
    nginx_installed=$(sudo dpkg -s nginx | grep Status | egrep "Status: install ok installed")
    backports_list_present=$(sudo find /etc/apt/sources.list.d/backports.list)
    certbot_installed=$(sudo dpkg -s certbot | grep Status | egrep "Status: install ok installed")
    python_certbot_nginx_installed=$(sudo dpkg -s "python-certbot-nginx" | grep "Status" )
    localcrt=$(find /etc/nginx/ -maxdepth 1 -name cert.crt -type f )
    localkey=$(find /etc/nginx/ -maxdepth 1 -name cert.key -type f )
    nginx_conf_https=$(sudo egrep "cert.pem" /etc/nginx/nginx.conf 2>/dev/null)
    nginx_conf_https_localcrt=$(sudo egrep "cert.crt" /etc/nginx/nginx.conf 2>/dev/null)
  else
    ERROR "Unable to check certificates, IPv4 public address not found, exiting!"
    exit 1
  fi
 
}

backup_certificate() {
  DEBUG "Backup directory with certificate to NFS"
  remote_backup_exists=$(find  "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}" -maxdepth 1 -type f -path "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz")
  DEBUG "remote_backup_exists: $remote_backup_exists"
  if [[ -n "$remote_backup_exists" ]];then
    DEBUG "Backup previous archive to ${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz.OLD"
    md5sum_remote=$(sudo md5sum ${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz | cut -f 1 -d ' ')
    DEBUG "md5sum_remote: $md5sum_remote"
    sudo mv -f "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz" "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz.OLD"
  fi
  cd /tmp/
  command_output=$(sudo GZIP=-n tar -czvf certBackup-${public_ipv4_2text}.tar.gz /etc/letsencrypt/ 2>&1)
  command_status="$?"
  DEBUG "Command tar output: $command_output"
  md5sum_local=$(sudo md5sum /tmp/certBackup-${public_ipv4_2text}.tar.gz | cut -f 1 -d ' ')
  DEBUG "md5sum_local: $md5sum_local"
  DEBUG "md5sum_remote: $md5sum_remote"
  if [[ "$md5sum_local" != "$md5sum_remote"  ]];then
    INFO "Copy backup to NFS"
    #cp /tmp/certBackup-${public_ipv4_2text}.tar.gz "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}"
    sudo rsync -av --no-perms --no-owner --no-group --omit-dir-times --delete --progress /tmp/certBackup-${public_ipv4_2text}.tar.gz "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}"
    sudo chmod 600 ${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz
  else
    INFO "Do not copy backup, local and NFS backups are the same md5sum"
  fi
  sudo rm /tmp/certBackup-${public_ipv4_2text}.tar.gz
  cd "$SCRIPTDIR"

  DEBUG "Set permissions on all existing backups"
  for file in `find "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}" -name certBackup\*`; do command_output=$(sudo chmod 600 $file); DEBUG "chmod $file" ; done
  DEBUG "Check after backup"
  remote_backup_exist_after_copy=$(find  "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}" -maxdepth 1 -type f -path "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz")
  DEBUG "remote_backup_exist_after_copy: $remote_backup_exist_after_copy"
  if [[ -n  "$remote_backup_exist_after_copy" ]];then
    OK "Backup completed: $remote_backup_exist_after_copy"
  else
    ERROR "Unable to find backup file: $remote_backup_exist_after_copy"
  fi
}

set_rserverconf() {
  rserverconf=$(sudo cat /etc/rstudio/rserver.conf | egrep "www-address")
  if [[ -z "$rserverconf" ]];then
    DEBUG "Edit /etc/rstudio/rserver.conf"
    sudo chmod 644 /etc/rstudio/rserver.conf
    sudo chown root: /etc/rstudio/rserver.conf
    command_output=$(echo "www-address=127.0.0.1" | sudo tee -a /etc/rstudio/rserver.conf 2>&1)
    DEBUG "command_output: $command_output"
  fi
}


unset_rserverconf() {
  if [[ -n `sudo cat /etc/rstudio/rserver.conf | egrep "www-address"` ]];then
    DEBUG "Restore clean rserver.conf"
    command_output=$(sudo rsync -av  --delete --progress ./conf/rserver.conf.clean /etc/rstudio/rserver.conf 2>&1)
    DEBUG "command_output: $command_output"
    sudo chmod 644 /etc/rstudio/rserver.conf
    sudo chown root: /etc/rstudio/rserver.conf
  fi
}

create_localcrt(){
  DEBUG "Gioing to create local certificate"
  command_output=$(sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/cert.key -out /etc/nginx/cert.crt -subj "/C=${LOCAL_CRT_C}/ST=${LOCAL_CRT_ST}/L=${LOCAL_CRT_L}/O=${LOCAL_CRT_O}/CN=${public_ipv4_name}" 2>&1)
  DEBUG "command_output: $command_output"
}

remove_localcrt(){
  if [[ -f /etc/nginx/cert.key ]];then
    DEBUG "Remove local certificate key"
    sudo rm -f /etc/nginx/cert.key
  fi

  if [[ -f /etc/nginx/cert.crt ]];then
    DEBUG "Remove local certificate"
    sudo rm -f /etc/nginx/cert.crt
  fi
}

restart_services() {
  sudo service rstudio-server restart
  sudo systemctl restart nginx
}

checkstate

update_motd() {
  if [[ -n "$chain_exists" ]] || [[ -n "$key_exists" ]] || [[ -n "$cert_path" ]] || [[ -n "$key_path" ]] || [[ -n "$FORCE" ]] && [[ -n "$nginx_conf_https" ]];then
    RSTUDIO_URL="Rstudio available at https://${public_ipv4_name}"
  elif [[ -n "$localcrt" ]] && [[ -n "$localkey" ]] && [[ -n "$nginx_conf_https_localcrt" ]];then
    RSTUDIO_URL="Rstudio available at https://${public_ipv4_name}"
  elif [[ -z "$nginx_conf_https" ]] && [[ -z "$nginx_conf_https_localcrt" ]];then
    RSTUDIO_URL="Rstudio available at http://${public_ipv4}:8787"
  fi
  if [[ "$MODE" != "status" ]];then
    INFO "$RSTUDIO_URL"
    if [[ -z "$nginx_conf_https" ]] && [[ -z "$nginx_conf_https_localcrt" ]];then
      ERROR "No certificate configured for HTTPS, please note that HTTP is unsecured!"
    fi
  fi
  if [[ -n "$RSTUDIO_URL" ]];then
    sudo sed -i "s|Rstudio available at.*using account|$RSTUDIO_URL using account|g" /etc/motd
  fi
}

DEBUG "MODE: $MODE"
if [[ "$MODE" == "status" ]];then
  DEBUG "chain_exists: $chain_exists"
  DEBUG "key_exists: $key_exists"
  DEBUG "cert_path: $cert_path"
  DEBUG "key_path: $key_path"
  DEBUG "nginx_installed: $nginx_installed"
  DEBUG "backports_list_present: $backports_list_present"
  DEBUG "certbot_installed: $certbot_installed"
  DEBUG "python_certbot_nginx_installed: $python-certbot-nginx_installed"
  DEBUG "nginx_conf_https: $nginx_conf_https"
  DEBUG "nginx_conf_https_localcrt: $nginx_conf_https_localcrt"

  if [[ -n "$chain_exists" ]] || [[ -n "$key_exists" ]] || [[ -n "$cert_path" ]] || [[ -n "$key_path" ]] || [[ -n "$FORCE" ]] && [[ -n "$nginx_conf_https" ]];then
    OK "Certificate OK"
    INFO "Rstudio available at https://${public_ipv4_name}"
  elif [[ -n "$localcrt" ]] && [[ -n "$localkey" ]] && [[ -n "$nginx_conf_https_localcrt" ]];then
    OK "Local certificate exists, OK"
    INFO "Rstudio available at https://${public_ipv4_name}
Please note that using self signed certificate need this step: In Browser Allow Self Signed Certificate: button Advanced -> Add Exception / Accept the Risk and Continue."
  elif [[ -z "$nginx_conf_https" ]] && [[ -z "$nginx_conf_https_localcrt" ]];then
    ERROR "No certificate configured for HTTPS, please note that HTTP is unsecured!
Consider deploying a certificate executing startHTTPS or startHTTPSlocalCrt commands."
    INFO "Rstudio available at http://${public_ipv4}:8787"
  else
    ERROR "Error during certificate check:"
    DEBUG "chain_exists: $chain_exists"
    DEBUG "key_exists: $key_exists"
    DEBUG "cert_path: $cert_path"
    DEBUG "key_path: $key_path"
    DEBUG "nginx_installed: $nginx_installed"
    DEBUG "backports_list_present: $backports_list_present"
    DEBUG "certbot_installed: $certbot_installed"
    DEBUG "python_certbot_nginx_installed: $python-certbot-nginx_installed"
  fi

elif [[ "$MODE" == "localcrt" ]];then
  create_localcrt

  # Set Rstudio-server conf                                                                                                                                        set_rserverconf

  checkstate
  if [[ -n "$localcrt" ]] && [[ -n "$localkey" ]];then
    DEBUG "Copy prepared /etc/nginx/nginx.conf"
    sudo cp ./conf/nginx.conf /etc/nginx/nginx.conf
    sudo chmod 644 /etc/nginx/nginx.conf
    sudo chown root: /etc/nginx/nginx.conf
    # Replace certificate in conf file
    if [[ -n "$public_ipv4_2text" ]];then
      DEBUG "Edit /etc/nginx/nginx.conf"
      sudo sed -i "s|[ ]*ssl_certificate [ ]*.*|    ssl_certificate    /etc/nginx/cert.crt;|g" /etc/nginx/nginx.conf
      sudo sed -i "s|[ ]*ssl_certificate_key [ ]*.*|    ssl_certificate_key       /etc/nginx/cert.key;|g" /etc/nginx/nginx.conf
      sudo sed -i "s|[ ]*proxy_redirect[ ]*.*|      proxy_redirect       http://localhost:8787 https://${public_ipv4};|g" /etc/nginx/nginx.conf
      sudo sed -i "s|[ ]*server_name [ ]*.*|    server_name ${public_ipv4};|g" /etc/nginx/nginx.conf

      # Restart services
      INFO "Restarting rstudio-server and nginx"
      restart_services
    fi
  fi

elif [[ "$MODE" == "backup" ]];then
  DEBUG "MODE: $MODE"
  if [[ -n "$chain_exists" ]] && [[ -n "$key_exists" ]] && [[ -n "$cert_path" ]] && [[ -n "$key_path" ]];then
    backup_certificate
  else
    WARN "Backup skipped because of issue checking certificate to backup!"
  fi

elif [[ "$MODE" == "http" ]];then
  DEBUG "Revert to http only"
  cd $SCRIPTDIR

  DEBUG "Restore clean nginx.conf"
  command_output=$(sudo rsync -av  --delete --progress ./conf/nginx.conf.clean /etc/nginx/nginx.conf 2>&1)
  DEBUG "command_output: $command_output"

  sudo chmod 644 /etc/nginx/nginx.conf
  sudo chown root: /etc/nginx/nginx.conf

  # Set back to clean rstudio-server conf
  unset_rserverconf

  # For local certificate
  remove_localcrt

  restart_services

elif  [[ "$MODE" == "https" ]] || [[ "$MODE" == "restore" ]];then
  remote_backup_exist=$(find  "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}" -maxdepth 1 -type f -path "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz")
  if [[ -n "$remote_backup_exist" ]] && [[ "$MODE" == "https" ]];then
    INFO "Change MODE to restore, because of existing backup file: $remote_backup_exist"
    MODE="restore"
  fi
  if [[ "$MODE" == "https" ]];then
    DEBUG "Create certificate and setup Nginx to run Rstudio over HTTPS"
  fi
  if [[ "$MODE" == "restore" ]];then
    DEBUG "Restore backup directory with certificate from NFS to local disc"
    command_output=$(sudo rm /tmp/certBackup-${public_ipv4_2text}.tar.gz 2>&1)
    #remote_backup_exist=$(find  "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}" -maxdepth 1 -type f -path "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz")
    if [[ -n "$remote_backup_exist" ]];then
      sudo rm -rf /etc/letsencrypt/
      sudo mkdir -p /etc/letsencrypt

      command_output=$(rsync -av --no-perms --no-owner --no-group --omit-dir-times --delete --progress "${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz" /tmp/ 2>&1)
      cd /tmp/
      command_output=$(sudo tar -xzvf /tmp/certBackup-${public_ipv4_2text}.tar.gz -C "/" 2>&1)
      command_status="$?"
      DEBUG "Command tar output: $command_output"
      if [[ "$command_status" -eq 0 ]];then
        OK "Restore completed"
      else
        ERROR "Unable to restore backup file"
      fi
      # Remove /tmp/certBackup-${public_ipv4_2text}.tar.gz
      command_output=$(sudo rm /tmp/certBackup-${public_ipv4_2text}.tar.gz 2>&1)
      DEBUG "command_output: $command_output"
      cd "$SCRIPTDIR"
    else
      ERROR "Unable to find backup file ${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz, exiting!"
      exit 1
    fi
    checkstate
    if [[ -z "$chain_exists" ]] || [[ -z "$key_exists" ]] || [[ -z "$cert_path" ]] || [[ -z "$key_path" ]] || [[ -n "$FORCE" ]];then
      ERROR "Unable to find certificate after restore from backup file ${NFS_HOME_PERSISTENT}/${USER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}/certBackup-${public_ipv4_2text}.tar.gz, exiting!"
      exit 1
    fi
  fi

  # Set Rstudio-server conf
  set_rserverconf

  # Add backports to your sources.list
  if [[ -z "$backports_list_present" ]]; then
    DEBUG "Add /etc/apt/sources.list.d/backports.list"
    command_output=$(echo "deb http://deb.debian.org/debian stretch-backports main" | sudo tee -a /etc/apt/sources.list.d/backports.list 2>&1)
    DEBUG "command_output: $command_output"
    command_output=$(sudo apt-get update 2>&1)
    DEBUG "command_output: $command_output"

  fi

  # Install Nginx
  if [[ -z "$nginx_installed" ]];then
    DEBUG "Install nginx"
    command_output=$(sudo apt-get update; sudo apt-get -y install nginx 2>&1)
    DEBUG "command_output: $command_output"
  fi

  # Install a package from backports
  if [[ -z "$certbot_installed" ]] || [[ -z "$python_certbot_nginx_installed" ]];then
    DEBUG "Install certbot"
    command_output=$(sudo apt-get update; apt-get -y install certbot python-certbot-nginx -t stretch-backports 2>&1)
    DEBUG "command_output: $command_output"
  fi

  # Get and install your certificates
  backup_now=0
  if [[ "$MODE" == "https" ]] && ( [[ -z "$chain_exists" ]] || [[ -z "$key_exists" ]] || [[ -z "$cert_path" ]] || [[ -z "$key_path" ]] || [[ -n "$FORCE" ]] ) ;then
    DEBUG "Obtain certificate"
    sudo certbot certonly --nginx --non-interactive --agree-tos --domains "${public_ipv4_name}" -m "$BIOUSER_EMAIL" --force-renewal
    sudo certbot certificates
    certbot_status="$?"

    set_rserverconf

    # After successfull certificate creation proceed with backup now
    if [[ "$certbot_status" -eq 0 ]];then
      backup_now=1
    fi
  else
    INFO "Certificate exists already, not to obtain new one."
    WARN "If required new one really, please delete backup files and use FORCE parameter. (For experienced users only!)"
    WARN "Genereating new certificate may lead to exceed rate limit. Please check by name ${public_ipv4_name} at https://transparencyreport.google.com/https/certificates"
  fi

  checkstate
  if [[ "$MODE" == "https" ]] && [[ "$backup_now" -eq 1 ]] && ( [[ -n "$chain_exists" ]] && [[ -n "$key_exists" ]] && [[ -n "$cert_path" ]] && [[ -n "$key_path" ]] );then
    DEBUG "Perform backup after succesffull certificate creation"
    backup_certificate
  fi


  if [[ -n "$chain_exists" ]] || [[ -n "$key_exists" ]] || [[ -n "$cert_path" ]] || [[ -n "$key_path" ]] || [[ -n "$FORCE" ]];then  
    DEBUG "Copy prepared /etc/nginx/nginx.conf"
    sudo cp ./conf/nginx.conf /etc/nginx/nginx.conf
    sudo chmod 644 /etc/nginx/nginx.conf
    sudo chown root: /etc/nginx/nginx.conf

    cert_path=$(sudo find /etc/letsencrypt/live/ -name cert.pem | head -n 1)
    key_path=$(sudo find /etc/letsencrypt/live/ -name privkey.pem | head -n 1)

    if [[ -n "$public_ipv4_2text" ]];then
      DEBUG "Edit /etc/nginx/nginx.conf"
      sudo sed -i "s|[ ]*ssl_certificate [ ]*.*|    ssl_certificate    ${cert_path};|g" /etc/nginx/nginx.conf
      sudo sed -i "s|[ ]*ssl_certificate_key [ ]*.*|    ssl_certificate_key       ${key_path};|g" /etc/nginx/nginx.conf
      sudo sed -i "s|[ ]*proxy_redirect[ ]*.*|      proxy_redirect       http://localhost:8787 https://${public_ipv4};|g" /etc/nginx/nginx.conf
      sudo sed -i "s|[ ]*server_name [ ]*.*|    server_name ${public_ipv4};|g" /etc/nginx/nginx.conf

      # Restart services
      INFO "Restarting rstudio-server and nginx"
      restart_services

    fi
  fi

elif [[ "$MODE" == "renew" ]];then
  DEBUG "Renew existing certificate"
  if [[ -n "$chain_exists" ]] || [[ -n "$key_exists" ]] || [[ -n "$cert_path" ]] || [[ -n "$key_path" ]];then
    sudo certbot renew
  fi




fi

checkstate
update_motd

# Exit
exit 0
