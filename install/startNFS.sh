#!/bin/bash
PATH=$PATH;PATH+=":/bin" ;PATH+=":/usr/bin";PATH+=":/usr/sbin";PATH+=":/usr/local/bin"; 
dirname=$(dirname $0)
cd "$dirname"
dirname=$(dirname pwd)
PATH+=":$dirname"
export PATH

CONF_DIR="$dirname"/conf

# Include global Conf
. $CONF_DIR/.conf

# Used to create/prolong session
MODE=
MODELIST="keytab passwdfile cron destroy status"
# Domain
if [[ -z "$REALM" ]];then
  echo "Empty REALM from conf. file, exiting!"
  exit 1
fi
# Frontend
if [[ -z "$FRONTEND" ]];then
  echo "Empty FRONTEND from conf. file, exiting!"
  exit 1
fi
if [[ -z "$FRONTEND_HOME" ]];then
  echo "Empty FRONTEND_HOME from conf. file, exiting!"
  exit 1
fi

# Username from home directory
USER=$(pwd | sed -rn "s/[/]*home[/]*([a-z0-9\-\_]+)[/]*.*/\1/p")
FORCE=

function_logger () {
    local tmp=$(echo "$1"| tr -s '\r\n' ';' |  sed '/^$/d')
    logger "`basename \"$0\"` $USER: $tmp"
    echo "$tmp"
}

# If without any parameters
if [[ $# -eq 0 ]]
  then

      echo "Mount/remount NFS storage using your META Password with kerberos ticket prolong as necessary.
Parameters:
-m Mode:
   keytab - One-purpose ticket /etc/krb5.keytab to mount NFS storage (Recommended).
   destroy - Destroy kerberos tickets and umount NFS storage.
   cron - Check periodically with prolong if needed.
   passwdfile - During first run as User save META password to file located at /home/${USER}/NFS/conf/.myNFSpassword
                Unsafe - password in local file! For testing purposes only!
-f Force remount using umount and destroy kerberos tickets.
-v Verbose output.

Example how to mount NFS storage at first login using your META password:
./startNFS.sh -m keytab
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
 [ "$_DEBUG" == "on" ] && [ ! "$MODE" == "cron" ] && echo -e "[${Yellow}DEBUG${Color_Off}] $@"
 [ "$_DEBUG" == "on" ] && [ "$MODE" == "cron" ] && echo -e "[DEBUG] $@"
}
function ERROR()
{
  [ ! "$MODE" == "cron" ] && echo -e "[${Red}ERROR${Color_Off}] $@"
  [ "$MODE" == "cron" ] && echo -e "[ERROR] $@"
}
function OK()
{
  [ ! "$MODE" == "cron" ] && echo -e "[${Green}OK${Color_Off}]    $@"
  [ "$MODE" == "cron" ] && echo -e "[OK]    $@"
}
function INFO()
{
  [ ! "$MODE" == "cron" ] && echo -e "[${Yellow}INFO${Color_Off}]  $@"
  [ "$MODE" == "cron" ] && echo -e "[INFO]  $@"
}

# There is no need to maintain passwd file in keytab mode!
if [[ "$MODE" == "keytab" ]];then
  # Remove if exists
  if [[ -f ./conf/.myNFSpassword ]];then
    WARN "REMOVE exiting myNFSpassword during keytab mode!"
    rm ./conf/.myNFSpassword
  fi
fi

# Get password if necessary
checkpasswd() {
  # Check if empty login/passw
  if [[ -f ./conf/.myNFSpassword ]];then
    INFO "Using password from file ./conf/.myNFSpassword"
    PASSWORD=$(cat ./conf/.myNFSpassword)
  else
    if [[ ! "$MODE" == "cron" ]] && [[ ! "$MODE" == "destroy" ]] && [[ ! "$MODE" == "status" ]];then
      # If mode is not cron, then fill in META password"
      read -s -p "Enter your Metacentrum Password to mount NFS storage: " PASSWORD
      if [[ "$MODE" == "passwdfile" ]];then
        echo "$PASSWORD" > ./conf/.myNFSpassword
      fi
      echo -e "\n"
    fi
  fi
}
checkpasswd

DEBUG "USER: $USER"

remount=0

# Get current mount state
checkstate() {
  # Check current state
  mounted=$(mount | egrep " /data ")
  klistuserexpired=$(klist | egrep ">>>Expired<<<")
  klistrootexpired=$(sudo klist | egrep ">>>Expired<<<")
  nfsexpired=$(ls -la /data/ 2>&1 | egrep "Key has expired")
  nfslist=$(ls -la /data/ 2>&1|egrep "persistent|shared" )
  klistuser=$(klist 2>&1 )
  klistroot=$(sudo klist 2>&1)
  keytab_exists=$(sudo /usr/bin/ktutil -k /etc/krb5.keytab list | grep "$REALM")
  DEBUG "mounted: $mounted"
  DEBUG "klistuserexpired: $klistuserexpired"
  DEBUG "klistrootexpired: $klistrootexpired"
  DEBUG "nfsexpired: $nfsexpired"
  DEBUG "nfslist:
  DEBUG "keytab_exists: $keytab_exists"
$nfslist"
  DEBUG "klistuser:
$klistuser"
  DEBUG "klistroot:
$klistroot"
}

# Destroy kerberos tickets and umount NFS storage
destroyall(){
  DEBUG "Umount/kdestroy"
  kdestroy -A 2>&1
  sudo kdestroy -A 2>&1
  sudo umount /data/ 2>&1
  sudo rm /etc/krb5.keytab
  if [[ -n "$FORCE" ]] || [[ "$MODE" == "keytab" ]];then
    rm ./conf/.myNFSpassword
  fi
  remount=1
}

# Check if mounted and klist not expired
checkstate

if [[ "$MODE" == "status" ]];then
  if [[ -n "$mounted" ]] && [[ -n "$nfslist" ]] && [[ -z "$nfsexpired" ]] && [[ -z "$klistuserexpired" ]] && [[ -z "$klistrootexpired" ]] && [[ -n "$keytab_exists" ]];then
    OK "NFS check OK"
    exit 0
  else
    ERROR "Error during NFS check!"
    INFO "Consider to execute command stopNFS followed with startNFS to mount storage again."
    exit 1
  fi
fi

# Perform re/mount for selected mode
if [[ "$MODE" == "destroy" ]];then
  DEBUG "Destroy all kerberos tickets and umount NFS storage"
  destroyall

elif [[ "$MODE" == "keytab" ]];then
  if [[ -n "$FORCE" ]];then
    DEBUG "Forced umount/kdestroy"
    destroyall
  fi

  if [[ -n "$PASSWORD" ]];then
    # kinit for user/root
    echo "$PASSWORD" | kinit --renewable --password-file=STDIN "$USER"@"$REALM"
    echo "$PASSWORD" | sudo kinit --renewable --password-file=STDIN "$USER"@"$REALM"

    # Obtain keytab
    DEBUG "Obtain keytab"
    INFO "Add frontend $FRONTEND to known_hosts file"
    ssh-keyscan -H "$FRONTEND" >> /home/"$USER"/.ssh/known_hosts
    DEBUG "Destroy kerberos ticket
    ssh "$USER"@"$FRONTEND" 'kdestroy -A'
    DEBUG "Initilazize at frontend
    echo "$PASSWORD"| ssh "$USER"@"$FRONTEND" 'kinit'
    #ssh "$USER"@"${FRONTEND}" '/software/remctl-2.12/bin/remctl -d kdccesnet.ics.muni.cz accounts nfskeytab >krb5.keytab'
    echo -e "${PASSWORD}\n${PASSWORD}" | ssh "$USER"@"${FRONTEND}" 'ktutil -k krb5.keytab add -p '"$USER"'@'"$REALM"' -e aes256-cts -V 1'
    INFO "Copying krb5.keytab"
    scp "$USER"@"${FRONTEND}:${FRONTEND_HOME}/${USER}"/krb5.keytab .
    sudo mv krb5.keytab /etc/krb5.keytab
    sudo chmod 600 /etc/krb5.keytab
    sudo  chown root: /etc/krb5.keytab
    # Permission for user to use keytab to prolong ticket
    sudo setfacl -R -m u:"$USER":rw /etc/krb5.keytab ;sudo setfacl -R -m g:"$USER":rw /etc/krb5.keytab

    # Check keytab
    keytab_err=$(sudo /usr/bin/ktutil -k /etc/krb5.keytab list | grep "$REALM")
    keytab_err_status="$?"
    if [[ "$keytab_err_status" -ne 0 ]];then
      ERROR "Unable to obtain keytab: $keytab_exists"
      exit 1
    fi

    # Remove keytab at frontend
    ssh "$USER"@"$FRONTEND" 'rm '"${FRONTEND_HOME}/${USER}"'/krb5.keytab'
    ssh "$USER"@"$FRONTEND" 'kdestroy -A'

    # crontab after reboot
    crontab_exists=$(crontab -l 2>/dev/null | egrep "krb5.keytab")
    if [[ -z "$crontab_exists" ]];then
      (crontab -l 2>/dev/null || true; echo "@reboot [ -f /etc/krb5.keytab ] && kinit -k -t /etc/krb5.keytab "$USER"@"$REALM" && sudo kinit -k -t /etc/krb5.keytab "$USER"@"$REALM" && sudo mount -a") | crontab -
    fi

    remount=1
  fi

elif [[ "$MODE" == "cron" ]];then
  if [[ -n "$keytab_exists" ]];then
     DEBUG "Prolong user session from keytab"
     /usr/bin/kinit -k -t /etc/krb5.keytab "$USER"@"$REALM"
     sudo /usr/bin/kinit -k -t /etc/krb5.keytab "$USER"@"$REALM"

  elif [[ -n "$PASSWORD" ]];then
    # Old mode using password in file

    if ( [[ -z "$mounted" ]] || ([[ -n "$mounted" ]] && ( [[ -n "$klistuserexpired" ]] || [[ -n "$klistrootexpired" ]] || [[ -n "$nfsexpired" ]]) ) ) && [[ -f ./conf/.myNFSpassword ]];then
      DEBUG "If not mounted yet, destroy previous kerberos tickets in passwd mode"
      destroyall
      remount=1
    fi

    /usr/bin/kinit --password-file=./conf/.myNFSpassword "$USER"@"$REALM"
    sudo /usr/bin/kinit --password-file=./conf/.myNFSpassword "$USER"@"$REALM"

  fi


elif [[ "$MODE" == "passwdfile" ]];then
  # Old mode using password in file
  if [[ -n "$FORCE" ]];then
    DEBUG "Forced umount/kdestroy"
    destroyall
    # Get password after destroyall
    checkpasswd
  fi
  # Kerberos ticket
  /usr/bin/kinit --password-file=./conf/.myNFSpassword "$USER"@"$REALM"
  sudo /usr/bin/kinit --password-file=./conf/.myNFSpassword "$USER"@"$REALM"
  remount=1

else
  if [[ -z "$PASSWORD" ]];then
    ERROR "Empty META password, exiting!"
  fi
  if [[ -z "$USER" ]];then
    ERROR "Empty META user, exiting!"
  fi
  exit 1

fi

if [[ ! "$MODE" == "destroy" ]];then
  DEBUG "MODE: $MODE"
  # Remount if neccessary
  if [[ -n "$FORCE" ]] || [[ "$remount" -eq 1 ]];then
    INFO "Mounting NFS storage"
    sudo mount -a
  fi

  # Get mount state after re/mount
  checkstate

  # Final info
  if [[ -n "$mounted" ]] && [[ -z "$klistuserexpired" ]] && [[ -z "$klistrootexpired" ]] && [[ -z "$nfsexpired" ]];then
    if [[ "$remount" -eq 1 ]];then
      OK "Attempt to re/mount NFS successfull"
    else
      OK "Mount OK"
    fi
  else
    ERROR "Issue to mount NFS storage, please check it!"
    exit 1
  fi
else
  # Get mount state after re/mount
  checkstate
  if [[ -z "$mounted" ]];then
    OK "Umount successfull"
  else
    ERROR "Issue to umount NFS storage, please check it!"
    exit 1
  fi

fi

exit 0
