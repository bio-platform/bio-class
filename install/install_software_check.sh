#!/bin/bash
# Installed software check
PATH=$PATH;PATH+=":/bin" ;PATH+=":/usr/bin";PATH+=":/usr/sbin";PATH+=":/usr/local/bin"; 
dirname=$(dirname $0)
cd "$dirname"
SCRIPTDIR=$(pwd)
dirname=$(dirname pwd)
PATH+=":$dirname"
export PATH

CONF_DIR="$dirname"/../conf
LIB_DIR="$dirname"/../lib

MODE=
MODELIST="status updateOS updateBIOSW updateREPO"

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

      echo "Update/Check software for biology students.
Parameters:
-m Mode:
   status  - Installed software check
   updateBIOSW - Update BIO Software
   updateOS - Update OS
   updateREPO - Update repository and maintenance scripts
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

BIOUSER=$(curl -s  http://169.254.169.254/openstack/2016-06-30/meta_data.json 2>/dev/null | python -m json.tool | egrep -i Bioclass_user |cut -f 2 -d ':' | tr -d ' ' | tr -d '"' | tr '[:upper:]' '[:lower:]')
if [[ -z "$BIOUSER" ]]; then
  echo "Empty Bioclass_user from METADATA, exiting!"
  exit 1
fi

# Checks

function_echo_output() {
  echo "---------${SW_NAME}---------"
  if [[ "$command_status" -ne 0 ]] || [[ -z "$command_output" ]];then
    echo "---ERROR---
Unable to check if installed $SW_NAME
---ERROR---"
  fi
  echo "${command_output}"
  echo $'\n'
}

if [[ "$MODE" == "status" ]];then
  echo "Installed software check"
  SW_NAME="bsmap"
  command_output=$(bsmap -h 2>&1| egrep "Usage")
  command_status="$?"
  function_echo_output

  SW_NAME="gmap"
  command_output=$(gmap --version 2>&1 | egrep "GMAP version ")
  command_status="$?"
  function_echo_output

  SW_NAME="picard"
  command_output=$(java -jar /opt/bio-class/picard-2.20.2/picard.jar -h 2>&1| egrep "\[-h\]" | sed 's/\x1B\[[0-9;]\+[A-Za-z]//g')
  command_status="$?"
  function_echo_output

  SW_NAME="salmon"
  command_output=$(salmon --version)
  command_status="$?"
  function_echo_output

  SW_NAME="multiqc"
  command_output=$(multiqc --version 2>&1 | egrep "version")
  command_status="$?"
  function_echo_output

  SW_NAME="fastq-dump"
  command_output=$(fastq-dump --version)
  command_status="$?"
  function_echo_output

  SW_NAME="bwa"
  command_output=$(bwa 2>&1| egrep "Usage")
  command_status="$?"
  function_echo_output

  SW_NAME="sratoolkit"
  command_output=$(fastqc --version)
  command_status="$?"
  function_echo_output

  SW_NAME="blastx"
  command_output=$(blastx -version)
  command_status="$?"
  function_echo_output

  SW_NAME="bowtie"
  command_output=$(bowtie --version 2>&1 | egrep "*bowtie*")
  command_status="$?"
  function_echo_output

  SW_NAME="bowtie2"
  command_output=$(bowtie2 --version | egrep "*bowtie*")
  command_status="$?"
  function_echo_output

  SW_NAME="canu"
  command_output=$(canu --help 2>&1 | egrep -i "Usage")
  command_status="$?"
  function_echo_output

  SW_NAME="fastq_to_fasta"
  command_output=$(fastq_to_fasta -h | egrep "usage")
  command_status="$?"
  function_echo_output

  SW_NAME="fastx_collapser"
  command_output=$(fastx_collapser -h | egrep -A 1 "usage")
  command_status="$?"
  function_echo_output

  SW_NAME="minimap2"
  command_output=$(minimap2 --help | egrep "Usage")
  command_status="$?"
  function_echo_output

  SW_NAME="mira"
  command_output=$(mira --help | egrep "version" | egrep "mira")
  command_status="$?"
  function_echo_output

  SW_NAME="racon"
  command_output=$(racon --help 2>&1  | egrep "^usage")
  command_status="$?"
  function_echo_output

  SW_NAME="fasta36"
  command_output=$(fasta36 --help | egrep -B 1 "version")
  command_status="$?"
  function_echo_output

  SW_NAME="cutadapt"
  command_output=$(cutadapt --help | egrep "version")
  command_status="$?"
  function_echo_output

  SW_NAME="cutadapt"
  command_output=$(pip list 2>&1 | grep cutadapt)
  command_status="$?"
  function_echo_output

  SW_NAME="umap-learn"
  command_output=$(pip list 2>&1 | grep umap-learn)
  command_status="$?"
  function_echo_output

  SW_NAME="htsfile"
  command_output=$(htsfile --version)
  command_status="$?"
  function_echo_output

  SW_NAME="samtools"
  command_output=$(samtools --version)
  command_status="$?"
  function_echo_output

  SW_NAME="bcftools"
  command_output=$(bcftools --version)
  command_status="$?"
  function_echo_output

  SW_NAME="trimmomatic"
  command_output=$(dpkg -s trimmomatic | egrep -B 1 "Status")
  command_status="$?"
  function_echo_output

  SW_NAME="miniasm"
  command_output=$(miniasm 2>&1 | egrep "Usage")
  command_status="$?"
  function_echo_output

  SW_NAME="soapdenovo2"
  command_output=$(dpkg -s soapdenovo2 | egrep -B 1 "Status")
  command_status="$?"
  function_echo_output

  SW_NAME="conda"
  command_output=$(conda --version)
  command_status="$?"
  function_echo_output

  SW_NAME="BiocManager"
  command_output=$(Rscript -e "BiocManager::version()")
  command_status="$?"
  function_echo_output

  echo "--------Checking BiocManager packages installed, please wait---------"

        spin='-\|/'
        spin_i=0

  installed=""; failed="";for i in Biobase BiocParallel DESeq2 DT GOstats GOsummaries GenomicAlignments GenomicFeatures Heatplus KEGG.db PoiClaClu RColorBrewer ReportingTools Rsamtools Seurat affy airway annotate arrayQualityMetrics beadarray biomaRt dendextend gdata genefilter goseq gplots gtools hgu133plus2cdf hgu133plus2probe hgu133plus2.db hwriter illuminaHumanv3.db lattice limma lumi made4 oligo org.Hs.eg.db org.Mm.eg.db org.Rn.eg.db pander pd.rat230.2 pheatmap preprocessCore qvalue rat2302.db rmarkdown sva tidyverse vsn xtable tximport EnsDb.Hsapiens.v75 AnnotationHub clusterProfiler enrichplot pathview SPIA edgeR; do spin_i=$(( (spin_i+1) %4 )); echo -en "\e[0K\r (${spin:$spin_i:1}) Checking: $i\e[1A" ;z=$(Rscript -e "a<-installed.packages(); packages<-a[,1];is.element(\"${i}\",packages)"); t=$(echo "$z" | grep TRUE); [ -n "$t" ] && installed+=" ${i}"; [ -z "$t" ] && failed+=" ${i}";echo; done ; [ -n "$installed" ] && echo -e "\nInstalled: $installed"; [ -n "$failed" ] && echo -e "\nERROR: $failed";

  echo -e "\n--------Check if BiocManager valid or need to update out-of-date packages---------"

  Rscript -e "BiocManager::valid()"

  # Checks
elif [[ "$MODE" == "updateBIOSW" ]];then
  echo -e "\n--------R update packages---------"
  sudo Rscript -e "update.packages(ask = FALSE)"
  echo -e "\n--------BiocManager update out-of-date packages---------"
  sudo Rscript -e "BiocManager::install(update = TRUE, ask = FALSE)"
  echo -e "\n--------Check if BiocManager valid or need to update out-of-date packages---------"
  sudo Rscript -e "BiocManager::valid()"

  #echo -e "\n--------Update installed BIOSW - in development---------"

elif [[ "$MODE" == "updateOS" ]];then
  echo -e "\n--------Update OS---------"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

elif [[ "$MODE" == "updateREPO" ]];then
  echo -e "\n--------Update bio-class repository---------"

    echo "BIOUSER: $BIOUSER"
    echo "SCRIPTDIR: $SCRIPTDIR"
    echo "CONF_DIR: $CONF_DIR"

  cd /home/debian/bio-class && sudo git pull --rebase
  if [[ $? -ne 0 ]];then
    cd /home/debian/bio-class && sudo git status
    # Backup repo
    if [[ -d /home/debian/bio-class ]];then
      echo "Moving repository to /home/debian/bio-class-backup"
      if [[ -d /home/debian/bio-class-backup ]];then
        sudo rm -rf /home/debian/bio-class-backup
      fi
        sudo mv /home/debian/bio-class /home/debian/bio-class-backup
      fi

    fi
    # Clone public repo
    cd "/home/debian/"
    sudo git clone https://github.com/bio-platform/bio-class.git 2>&1
  fi

  cd /home/debian/;
  if [[ ! -d /home/debian/bio-class ]];then
    if [[ -d /home/debian/bio-class-backup ]];then
      echo "ERROR to clone repository, using repository from image. Not updating configuration/scripts!"
      sudo mv /home/debian/bio-class-backup /home/debian/bio-class
    fi
  else
    #if [[ -d /home/debian/bio-class-backup ]];then
    #  sudo rm -rf /home/debian/bio-class-backup
    #fi

    echo -e "\n--------Update conf. files, service scripts---------"
    # Custom script to renew kerberos tickets
    sudo mkdir -p /var/lock/bio-class; cd /var/lock/; chown "${BIOUSER}": ./bio-class/
    echo -e "*/15 * * * * ${BIOUSER} cd /home/${BIOUSER}/NFS/ && /usr/bin/flock -w 10 /var/lock/bio-class/startNFS ./startNFS.sh -m cron >/dev/null 2>&1" | sudo tee /etc/cron.d/checkNFS
    cd "$SCRIPTDIR"
    sudo mkdir -p /home/"${BIOUSER}"/NFS/conf
    sudo cp ${SCRIPTDIR}/startNFS.sh /home/"${BIOUSER}"/NFS
    sudo cp ${CONF_DIR}/.conf /home/"${BIOUSER}"/NFS/conf
    sudo chown "${BIOUSER}": /home/"${BIOUSER}"/NFS -R
    sudo chmod +x /home/"${BIOUSER}"/NFS/startNFS.sh
    # Group for bioconductor
    sudo groupadd bioconductor
    sudo usermod -a -G bioconductor "${BIOUSER}"
    groups "${BIOUSER}"
    # RStudio Server: Running with a Proxy
    sudo mkdir -p /home/"${BIOUSER}"/HTTPS/conf
    sudo cp ${SCRIPTDIR}/startHTTPS.sh /home/"${BIOUSER}"/HTTPS
    sudo chown "${BIOUSER}": /home/"${BIOUSER}"/HTTPS -R
    sudo chmod +x /home/"${BIOUSER}"/HTTPS/startHTTPS.sh
    for file in ${CONF_DIR}/.conf ${CONF_DIR}/nginx.conf ${CONF_DIR}/nginx.conf.clean ${CONF_DIR}/rserver.conf.clean ; do \
    sudo cp $file /home/"${BIOUSER}"/HTTPS/conf ; done
    sudo chmod 644 /home/"${BIOUSER}"/HTTPS/conf/* ; sudo chown root: /home/"${BIOUSER}"/HTTPS/conf/*
    echo -e "\n--------Finished to update conf. files, service scripts---------"
  fi

  echo "List last 10 commits"
  cd /home/debian/bio-class && git log --pretty=format:"%cd %s" | head -n 10

  #echo -e "\n--------Update maintenance scripts - in development---------"
fi

exit 0
