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

# Set to true if in development
INDEVELOP=""
MODE=
MODELIST="pre base post all"

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
   pre  - Preinstall part for building image using Packer
   base - Software instalation part for building image using Packer
   post - Postinstall part for building image using Packer
   all  - Install all software during instance cloud-init (time consuming to download and install all required software during each instance cloud init)
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

# Create local user for Rstudio and set pasword, get bioclass sw selections (age,gaa)
BIOUSER=$(curl -s  http://169.254.169.254/openstack/2016-06-30/meta_data.json 2>/dev/null | python -m json.tool | egrep -i Bioclass_user |cut -f 2 -d ':' | tr -d ' ' | tr -d '"' | tr '[:upper:]' '[:lower:]')
if [[ -z "$BIOUSER" ]]; then 
  echo "Empty Bioclass_user from METADATA, using default login name: student"
  BIOUSER="student" 
fi
BIOUSER_EMAIL=$(curl -s  http://169.254.169.254/openstack/2016-06-30/meta_data.json 2>/dev/null | python -m json.tool | egrep -i Bioclass_email |cut -f 2 -d ':' | tr -d ' ' | tr -d '"' |sed 's/,$//g'| tr '[:upper:]' '[:lower:]')
if [[ -z "$BIOUSER_EMAIL" ]];then
  echo "Empty Bioclass_email from METADATA, using default email: jirasek@cesnet.cz"
  BIOUSER_EMAIL="jirasek@cesnet.cz"
fi
# If empty, then install all software
BIOSW=$(curl -s  http://169.254.169.254/openstack/2016-06-30/meta_data.json 2>/dev/null | python -m json.tool | egrep -i Bioclass_sw |cut -f 2 -d ':' | tr -d ' ' | tr -d '"'| tr -d ',')
if [[ "$BIOSW" == "none" ]];then
  BIOSW_AGE="" ; BIOSW_GAA=""; BIOSW_CONDA=""; BIOSW_RSTUDIO="rstudio";
elif [[ -z "$BIOSW" ]];then
  BIOSW_AGE="age" ; BIOSW_GAA="gaa"; BIOSW_CONDA="conda" ; BIOSW_RSTUDIO="rstudio";
else
  BIOSW_AGE=$(echo "$BIOSW" | egrep -i age | tr '[:upper:]' '[:lower:]') ;BIOSW_GAA=$(echo "$BIOSW" | egrep -i gaa | tr '[:upper:]' '[:lower:]');
  BIOSW_CONDA="conda" ; BIOSW_RSTUDIO="rstudio";
fi

echo "BIOUSER: $BIOUSER"
echo "BIOSW_AGE: $BIOSW_AGE"
echo "BIOSW_GAA: $BIOSW_GAA"

if [[ "$MODE" == "pre" ]] || [[ "$MODE" == "all" ]];then
  useradd -m "$BIOUSER"
  mkhomedir_helper "$BIOUSER"
  # Generate password for user "$BIOUSER"
  usermod -aG sudo "$BIOUSER"; usermod -s /bin/bash "$BIOUSER";
  apg -m 16 -n 1 -M sncl -E \'\`\\ > /home/"$BIOUSER"/rstudio-pass
  # Change "$BIOUSER" password
  RSTUDIO_PASSW=$(cat /home/"$BIOUSER"/rstudio-pass) ;echo -e "${RSTUDIO_PASSW}\n${RSTUDIO_PASSW}" | passwd "$BIOUSER"  ;
  # Copy .bashrc, alias ll
  cp /home/debian/.bashrc /home/"$BIOUSER"/.bashrc ;
  chown "$BIOUSER": /home/"$BIOUSER"/.bashrc; sed -i 's/# alias ll=\x27ls \$LS_OPTIONS -l\x27/alias ll=\x27ls \$LS_OPTIONS -alF\x27/g' /home/"$BIOUSER"/.bashrc
  # Allow members of group sudo to execute any command
  echo ""$BIOUSER" ALL=(ALL) NOPASSWD: ALL" >  /etc/sudoers.d/"$BIOUSER"  ; chmod 440 /etc/sudoers.d/"$BIOUSER"
fi

# Enable wget, dpkg, add support for https apt sources, dirmngr (network certificate management service) (network certificate management service)
apt-get -y install mc vim git dpkg-dev apt-transport-https ca-certificates dirmngr

  # Install required packages for R/R-Studio/S and other SW
  apt-get -y install libc6-dev cpp g++ zlib1g-dev devscripts build-essential \
rpm2cpio cpio libgstreamer-plugins-base1.0-0 libgstreamer1.0-0 libjpeg62 liborc-0.4-0 \
libxslt1-dev libedit2  libcurl4-openssl-dev libcairo2-dev mesa-common-dev libxt-dev libglu1-mesa-dev \
expect imagemagick dpkg-dev gdebi-core tmux libnspr4-dev libssl-doc libffi-dev libgdbm-dev \
libnspr4-dev libnss3-dev libssl-dev libssl-doc wget tmux acl x11-apps xfonts-base htop \
libqt5x11extras5 miniasm soapdenovo2 unixodbc-dev dnsutils

if ([[ -n "$BIOSW_RSTUDIO" ]] && [[ "$MODE" == "all" ]]) || [[ "$MODE" == "base" ]]; then
  # Source for R, add key, creating own repository for RSTUDIO
  LOCAL_RSTUDIO_REPO="/var/local-rstudio-repo"
  mkdir -p "$LOCAL_RSTUDIO_REPO"
  echo -e "deb https://cloud.r-project.org/bin/linux/debian stretch-cran35/"  > /etc/apt/sources.list.d/r.list
  # Secure APT - fetch and import the current key
  apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'
  echo "deb file:$LOCAL_RSTUDIO_REPO/ ./" > /etc/apt/sources.list.d/rstudio.list
  wget -P "$LOCAL_RSTUDIO_REPO" --no-verbose https://download2.rstudio.org/server/debian9/x86_64/rstudio-server-1.2.1335-amd64.deb
  wget -P $"$LOCAL_RSTUDIO_REPO" --no-verbose https://download1.rstudio.org/desktop/debian9/x86_64/rstudio-1.2.1335-amd64.deb
  # Create local repo for apt-get install, not use gdebi during VM init
  cd "$LOCAL_RSTUDIO_REPO"
  sudo dpkg-scanpackages . | gzip > ./Packages.gz
  cd "$SCRIPTDIR"
  update_sources ;

  # Installing R
  update_sources ; apt-get -y install r-base r-base-dev ; update_sources ;

  # Install Rstudio after R
  sudo apt-get -y --allow-unauthenticated install rstudio rstudio-server  ; update_sources ;

fi

if ([[ -n "$BIOSW_AGE" ]] && [[ "$MODE" == "all" ]]) || [[ "$MODE" == "base" ]]; then
  # BSMAP
  SW_NAME="bsmap";SW_VERSION="2.90";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/bsmap-${SW_VERSION}.tgz" ] && wget --no-verbose http://lilab.research.bcm.edu/dldcc-web/lilab/yxi/bsmap/bsmap-${SW_VERSION}.tgz -P "$TMP_DIR" ;
  mkdir -p "${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}"; tar -zxf "$(find "$TMP_DIR" -maxdepth 1 -name "${SW_NAME}*" -type f)" -C "${TMP_DIR}"
  cd "${TMP_DIR}/${SW_NAME}-${SW_VERSION}";  make -j $(nproc) ; DESTDIR="${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}" make install ;
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/usr/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/usr/bin" >> "${PATH_FILE}"

  # GMAP
  SW_NAME="gmap";SW_VERSION="2019-06-10";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/${SW_NAME}-gsnap-${SW_VERSION}.tar.gz" ] && wget --no-verbose http://research-pub.gene.com/gmap/src/${SW_NAME}-gsnap-${SW_VERSION}.tar.gz -P "${TMP_DIR}"
  mkdir -p "${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}"; tar -zxf "$(find "$TMP_DIR" -maxdepth 1 -name "${SW_NAME}*" -type f)" -C "${TMP_DIR}"
  cd "${TMP_DIR}/${SW_NAME}-${SW_VERSION}"; ./configure --prefix "${INSTALL_DIR}/gmap-${SW_VERSION}"
  make -j $(nproc) ; make install ;
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/bin" >> "${PATH_FILE}"

  # multiqc
  apt-get install -y python-pip
  pip install --upgrade multiqc

  # picard-tools  http://broadinstitute.github.io/picard/
  SW_NAME="picard";  SW_VERSION="2.20.2";
  mkdir -p "${INSTALL_DIR}/picard-${SW_VERSION}"
  [ ! -f "${TMP_DIR}/${SW_NAME}.jar" ] && wget --no-verbose https://github.com/broadinstitute/picard/releases/download/${SW_VERSION}/${SW_NAME}.jar -P "${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}"
  [ -f "${TMP_DIR}/${SW_NAME}.jar" ] && cp "${TMP_DIR}/${SW_NAME}.jar" "${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}"
  # TEST with: java -jar /opt/bio-class/picard-2.20.2/picard.jar -h  

  # salmon                                             
  SW_NAME="salmon";SW_VERSION="0.14.1";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/salmon-${SW_VERSION}_linux_x86_64.tar.gz" ] && wget --no-verbose https://github.com/COMBINE-lab/salmon/releases/download/v${SW_VERSION}/salmon-${SW_VERSION}_linux_x86_64.tar.gz -P "${TMP_DIR}"
  mkdir -p "${INSTALL_DIR}/${SW_NAME}-latest_linux_x86_64"; tar -zxf "$(find "$TMP_DIR" -maxdepth 1 -name "${SW_NAME}*" -type f)" -C "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-latest_linux_x86_64/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-latest_linux_x86_64/bin" >> "${PATH_FILE}"

  # sra-toolkit  test sra-sort, cg-load                                          
  SW_NAME="sratoolkit";SW_VERSION="2.9.6";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/sratoolkit.${SW_VERSION}-ubuntu64.tar.gz" ] && wget --no-verbose https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/${SW_VERSION}/sratoolkit.${SW_VERSION}-ubuntu64.tar.gz -P "${TMP_DIR}"
  mkdir -p "${INSTALL_DIR}/${SW_NAME}.${SW_VERSION}-ubuntu64"; tar -zxf "$(find "$TMP_DIR" -maxdepth 1 -name "${SW_NAME}*" -type f)" -C "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}.${SW_VERSION}-ubuntu64/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}.${SW_VERSION}-ubuntu64/bin" >> "${PATH_FILE}"

  # umap-learn
  pip install umap-learn

fi 
#BIOSW_AGE

if (([[ -n "$BIOSW_GAA" ]] || [[ -n "$BIOSW_AGE" ]]) && [[ "$MODE" == "all" ]]) || [[ "$MODE" == "base" ]]; then
  # BWA http://bio-bwa.sourceforge.net
  SW_NAME="bwa";SW_VERSION="0.7.1";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/bwa-${SW_VERSION}.tar.bz2" ] && wget --no-verbose https://sourceforge.net/projects/bio-bwa/files/bwa-${SW_VERSION}.tar.bz2 -P "${TMP_DIR}"
  mkdir -p "${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}"; tar -jxf "$(find "$TMP_DIR" -maxdepth 1 -name "${SW_NAME}*" -type f)" -C "${TMP_DIR}"
  cd "${TMP_DIR}/${SW_NAME}-${SW_VERSION}";  make -j $(nproc) ;  cp bwa "${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/" >> "${PATH_FILE}"

  # cutadapt
  apt-get install -y python{,3}-pip
  pip install --upgrade cutadapt
  pip3 install --upgrade cutadapt

  # fastqc
  apt-get -y install default-jre
  SW_NAME="fastqc";SW_VERSION="0.11.8";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/fastqc_v${SW_VERSION}.zip" ] && wget --no-verbose https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${SW_VERSION}.zip -P "${TMP_DIR}"
  unzip -q "${TMP_DIR}/fastqc_v${SW_VERSION}.zip" -d "${INSTALL_DIR}"
  chmod +x "${INSTALL_DIR}/FastQC/fastqc"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/FastQC/"; export PATH ; echo ":${INSTALL_DIR}/FastQC/" >> "${PATH_FILE}"

  # samtools - test htsfile for htslib
  apt-get install -y bzip2 libbz2-dev liblzma-dev libcurl4-openssl-dev libncurses-dev
  SAMTOOLS_SOFTWARE="htslib samtools bcftools"
  SAMTOOLS_VERSION="1.9"
  for software in ${SAMTOOLS_SOFTWARE}; do
    [ ! -f "${TMP_DIR}/${software}-${SAMTOOLS_VERSION}.tar.bz2" ] && wget --no-verbose https://github.com/samtools/${software}/releases/download/${SAMTOOLS_VERSION}/${software}-${SAMTOOLS_VERSION}.tar.bz2 -P "${TMP_DIR}"
    tar -jxf "${TMP_DIR}/${software}-${SAMTOOLS_VERSION}.tar.bz2" -C "${TMP_DIR}"
    cd "${TMP_DIR}/${software}-${SAMTOOLS_VERSION}"
    ./configure --prefix "${INSTALL_DIR}/${software}-${SAMTOOLS_VERSION}"
    make -j $(nproc) ;    make install ;
    PATH=$PATH;PATH+=":${INSTALL_DIR}/${software}-${SAMTOOLS_VERSION}/bin"; export PATH ; echo ":${INSTALL_DIR}/${software}-${SAMTOOLS_VERSION}/bin" >> "${PATH_FILE}"
  done

  # trimmomatic
  apt-get install -y trimmomatic

fi
#BIOSW_GAA || $BIOSW_AGE


if ([[ -n "$BIOSW_GAA" ]] && [[ "$MODE" == "all" ]]) || [[ "$MODE" == "base" ]];then

  #install_blast
  SW_NAME="blast";SW_VERSION="2.9.0";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/ncbi-blast-${SW_VERSION}+-x64-linux.tar.gz" ] && wget --no-verbose  ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${SW_VERSION}/ncbi-blast-${SW_VERSION}+-x64-linux.tar.gz -P "${TMP_DIR}"
  mkdir -p "${INSTALL_DIR}/ncbi-${SW_NAME}-${SW_VERSION}+"; tar -zxf "$(find "$TMP_DIR" -maxdepth 1 -name "ncbi-${SW_NAME}*" -type f)" -C "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/ncbi-${SW_NAME}-${SW_VERSION}+/bin"; export PATH ; echo ":${INSTALL_DIR}/ncbi-${SW_NAME}-${SW_VERSION}+/bin" >> "${PATH_FILE}"

  #install_bowtie                                               
  SW_NAME="bowtie";SW_VERSION="1.2.2";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/bowtie-${SW_VERSION}-linux-x86_64.zip" ] && wget --no-verbose https://sourceforge.net/projects/bowtie-bio/files/bowtie/${SW_VERSION}/bowtie-${SW_VERSION}-linux-x86_64.zip -P "${TMP_DIR}"
  unzip -q "${TMP_DIR}/${SW_NAME}-${SW_VERSION}-linux-x86_64.zip" -d "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}-linux-x86_64/"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}-linux-x86_64/" >> "${PATH_FILE}"

  #install_bowtie2
  SW_NAME="bowtie2";SW_VERSION="2.3.5.1";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/bowtie2-${SW_VERSION}-linux-x86_64.zip" ] && wget --no-verbose https://sourceforge.net/projects/bowtie-bio/files/bowtie2/${SW_VERSION}/bowtie2-${SW_VERSION}-linux-x86_64.zip -P "${TMP_DIR}"
  unzip -q "${TMP_DIR}/${SW_NAME}-${SW_VERSION}-linux-x86_64.zip" -d "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}-linux-x86_64/"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}-linux-x86_64/" >> "${PATH_FILE}"

  #install_canu                                              
  SW_NAME="canu";SW_VERSION="1.8";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/canu-${SW_VERSION}.Linux-amd64.tar.xz" ] && wget --no-verbose https://github.com/marbl/canu/releases/download/v${SW_VERSION}/canu-${SW_VERSION}.Linux-amd64.tar.xz -P "${TMP_DIR}"
  tar -xf "${TMP_DIR}/${SW_NAME}-${SW_VERSION}.Linux-amd64.tar.xz" -C "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/Linux-amd64/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/Linux-amd64/bin" >> "${PATH_FILE}"

  #install_fastx
  apt-get install -y pkg-config libgtextutils-dev
  SW_NAME="fastx_toolkit";SW_VERSION="0.0.14";
    [ ! -f "${TMP_DIR}/fastx_toolkit-${SW_VERSION}.tar.bz2" ] && wget --no-verbose https://github.com/agordon/fastx_toolkit/releases/download/${SW_VERSION}/fastx_toolkit-${SW_VERSION}.tar.bz2 -P "${TMP_DIR}"
    tar -jxf "${TMP_DIR}/${SW_NAME}-${SW_VERSION}.tar.bz2" -C "${TMP_DIR}"
    cd "${TMP_DIR}/${SW_NAME}-${SW_VERSION}"
    ./configure --prefix "${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}"
    make -j $(nproc)
    make install
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}/bin" >> "${PATH_FILE}"
  
  #install_miniasm
  apt-get install -y miniasm

  #install_minimap2
  SW_NAME="minimap2";SW_VERSION="2.17";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/minimap2-${SW_VERSION}_x64-linux.tar.bz2" ] && wget --no-verbose https://github.com/lh3/minimap2/releases/download/v${SW_VERSION}/minimap2-${SW_VERSION}_x64-linux.tar.bz2 -P "${TMP_DIR}"
  tar -jxf "${TMP_DIR}/${SW_NAME}-${SW_VERSION}_x64-linux.tar.bz2" -C "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}_x64-linux"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-${SW_VERSION}_x64-linux" >> "${PATH_FILE}"

  #install_mira
  # ERROR: The certificate of ‘kent.dl.sourceforge.net’ has expired. https://kent.dl.sourceforge.net/project/mira-assembler/MIRA/stable/mira_${SW_VERSION}_linux-gnu_x86_64_static.tar.bz2
  SW_NAME="mira";SW_VERSION="4.0.2";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/mira_${SW_VERSION}_linux-gnu_x86_64_static.tar.bz2" ] && wget --no-verbose https://sourceforge.net/projects/mira-assembler/files/MIRA/stable/mira_${SW_VERSION}_linux-gnu_x86_64_static.tar.bz2 -P "${TMP_DIR}"
  tar -jxf "${TMP_DIR}/mira_${SW_VERSION}_linux-gnu_x86_64_static.tar.bz2" -C "${INSTALL_DIR}"
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}_${SW_VERSION}_linux-gnu_x86_64_static/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}_${SW_VERSION}_linux-gnu_x86_64_static/bin" >> "${PATH_FILE}"

  #install_racon
  apt-get install -y cmake
  SW_NAME="racon";SW_VERSION="1.3.3";cd  "$TMP_DIR";
  [ ! -f "${TMP_DIR}/racon-v${SW_VERSION}.tar.gz" ] && wget --no-verbose https://github.com/isovic/racon/releases/download/${SW_VERSION}/racon-v${SW_VERSION}.tar.gz -P "${TMP_DIR}"
  tar -zxf "${TMP_DIR}/racon-v${SW_VERSION}.tar.gz" -C "${TMP_DIR}"
  cd "${TMP_DIR}/racon-v${SW_VERSION}/"
  mkdir build
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/racon-v${SW_VERSION}" ..
  make -j $(nproc)
  make install
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}-v${SW_VERSION}/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}-v${SW_VERSION}/bin" >> "${PATH_FILE}"

  #install_soapdenovo2
  apt-get install -y soapdenovo2

  #fasta36
  SW_NAME="fasta";SW_VERSION="36";cd "$INSTALL_DIR";
  git clone -q https://github.com/wrpearson/fasta36.git
  cd ./fasta36/src/ ; make -f ../make/Makefile.linux64 all
  PATH=$PATH;PATH+=":${INSTALL_DIR}/${SW_NAME}${SW_VERSION}/bin"; export PATH ; echo ":${INSTALL_DIR}/${SW_NAME}${SW_VERSION}/bin" >> "${PATH_FILE}"

fi

if ([[ -n "$BIOSW_RSTUDIO" ]] && [[ "$MODE" == "all" ]]) || [[ "$MODE" == "base" ]];then
  #R packages
  echo -e "#!/usr/bin/Rscript
install.packages(c(\"shiny\",\"devtools\",\"rsconnect\",\"httpuv\",\"rmarkdown\"))" >> "$TMP_DIR"/rstudiopackages.r
  cd "${TMP_DIR}"; Rscript rstudiopackages.r
  cd "$SCRIPTDIR"
fi

 
if ([[ -n "$BIOSW_AGE" ]] && [[ "$MODE" == "all" ]]) || [[ "$MODE" == "base" ]];then
  # Bioconductor  - Default R path /usr/bin/R
  apt-get install -y libssl-dev libmariadb-client-lgpl-dev libhdf5-dev
  echo -e "#!/usr/bin/Rscript

if (!requireNamespace(\"BiocManager\"))
    install.packages(\"BiocManager\")
    
BiocManager::install()

packages <- c(\"Biobase\",\"BiocParallel\",\"DESeq2\",\"DT\",\"GOstats\",\"GOsummaries\",\"GenomicAlignments\",\"GenomicFeatures\",\"Heatplus\",\"KEGG.db\",\"PoiClaClu\",\"RColorBrewer\",\"ReportingTools\",\"Rsamtools\",\"Seurat\",\"affy\",\"airway\",\"annotate\",\"arrayQualityMetrics\",\"beadarray\",\"biomaRt\",\"dendextend\",\"gdata\",\"genefilter\",\"goseq\",\"gplots\",\"gtools\",\"hgu133plus2cdf\",\"hgu133plus2probe\",\"hgu133plus2.db\",\"hwriter\",\"illuminaHumanv3.db\",\"lattice\",\"limma\",\"lumi\",\"made4\",\"oligo\",\"org.Hs.eg.db\",\"org.Mm.eg.db\",\"org.Rn.eg.db\",\"pander\",\"pd.rat230.2\",\"pheatmap\",\"preprocessCore\",\"qvalue\",\"rat2302.db\",\"rmarkdown\",\"sva\",\"tidyverse\",\"vsn\",\"xtable\",\"tximport\",\"EnsDb.Hsapiens.v75\",\"AnnotationHub\",\"clusterProfiler\",\"enrichplot\",\"pathview\",\"SPIA\",\"edgeR\")

BiocManager::install(packages)

for(package in packages) {
  if(package %in% rownames(installed.packages()) == FALSE) {
    stop(\"Package '\", package, \"' was not installed\")
  }
}
library(BiocManager)
BiocManager::valid()
BiocManager::install(update = TRUE, ask = FALSE)
BiocManager::valid()" >> "$TMP_DIR"/bioconductor.r
  cd "${TMP_DIR}"; Rscript bioconductor.r
  cd "$SCRIPTDIR"
fi

if ([[ -n "$BIOSW_CONDA" ]] && [[ "$MODE" == "all" ]]) || [[ "$MODE" == "base" ]]; then
  # bioconda
  [ ! -f "${TMP_DIR}/Miniconda3-latest-Linux-x86_64.sh" ] && wget --no-verbose https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -P "$TMP_DIR" ;
  cd "${TMP_DIR}"; bash ./Miniconda3-latest-Linux-x86_64.sh -b -p "${INSTALL_DIR}"/miniconda;
  PATH=$PATH;PATH+=":${INSTALL_DIR}/miniconda/bin:/opt/${name}/miniconda/condabin"; export PATH ; cd ${INSTALL_DIR}/miniconda ;
  echo ":${INSTALL_DIR}/miniconda/bin:/opt/${name}/miniconda/condabin" >> "${PATH_FILE}" ;
  source ${INSTALL_DIR}/miniconda/bin/activate ; conda update -y conda ;
  # conda show sources and installed packages before our install
  conda config --show-sources ;  conda list;
  # Add conda chanels
  for item in defaults bioconda conda-forge; do conda config --add channels "$item" ; done
  # Show chanels, list after install
  conda config --show-sources ;  conda list;
fi
if [[ -n "$BIOSW_CONDA" ]] && [[ "$MODE" == "post" ]]; then
  # Set permissions for "$BIOUSER" account
  for item in "/opt/${name}/" "$TMP_DIR"; do
  chmod g+s "$item"; setfacl -dR -m g:"$BIOUSER":rwx "$item" ; setfacl -dR -m u:"$BIOUSER":rwx "$item" ;
  setfacl -R -m u:"$BIOUSER":rwx "$item" ;setfacl -R -m g:"$BIOUSER":rwx "$item" ;  done
  #conda info; conda list --show-channel-urls;

fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "base" ]]; then
  # NFS - kerberos
  mkdir -p /data/ ; DEBIAN_FRONTEND=noninteractive apt-get install -y krb5-config heimdal-clients nfs-common nfs-kernel-server;

  # Get krb5.conf
  mv /etc/krb5.conf /etc/krb5.conf.OLD ;
  wget -P "/etc/" --no-verbose https://metavo.metacentrum.cz/krb5.conf
  chmod 644 /etc/krb5.conf

  modprobe nfs;modprobe auth_rpcgss;

  # Test of support NFS file system, expected: nodev nfs4
  grep nfs4 /proc/filesystems ;
  # Test RPCSECsupport, expected: /proc/net/rpc/auth.rpcsec.context and /proc/net/rpc/auth.rpcsec.init
  ls -d /proc/net/rpc/auth.rpcsec* ;

  # nfs-client
  # Edit /etc/default/nfs-common
  sed -i 's/NEED_STATD=$/NEED_STATD=yes/g' /etc/default/nfs-common
  sed -i 's/STATDOPTS=.*/STATDOPTS=/g' /etc/default/nfs-common
  sed -i 's/NEED_IDMAPD=$/NEED_IDMAPD=yes/g' /etc/default/nfs-common
  sed -i 's/NEED_GSSD=$/NEED_GSSD=yes/g' /etc/default/nfs-common

  # Mapping of NFSv4 identities to local users
  sed -i 's/# Domain = localdomain$/Domain=META/g' /etc/idmapd.conf

  # Edit /lib/systemd/system/rpc-gssd.service
  sed -i 's/ConditionPathExists.*/ConditionPathExists=\/etc\/init.d\/nfs-common/g' /lib/systemd/system/rpc-gssd.service
  sed -i 's/ExecStart.*/ExecStart=\/usr\/sbin\/rpc.gssd -n \$GSSDARGS/g' /lib/systemd/system/rpc-gssd.service
  echo -e "RPCGSSDOPTS=\"-n\"" >> /etc/default/nfs-common
  systemctl daemon-reload
  systemctl restart rpc-gssd
  systemctl status rpc-gssd

  # Edit /etc/fstab
  sed -i '/^$/d' /etc/fstab; echo -e "storage-brno3-cerit.metacentrum.cz:/nfs4/projects/bioconductor\t/data/\tnfs4\tsec=krb5,vers=4\t0\t0\n" >> /etc/fstab
  # Start nfs and set auto start after reboot
  systemctl restart nfs-client.target ; systemctl status nfs-client.target;

  # without nfs-kernel-server installed, rpc.idmapd is no longer running
  ps aux | grep idmapd

  systemctl restart nfs-client.target ;
  systemctl restart rpc-gssd
  systemctl status rpc-gssd
fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "post" ]];then
  # Custom script to renew kerberos tickets
  mkdir -p /var/lock/bio-class; cd /var/lock/; chown "${BIOUSER}": ./bio-class/
  echo -e "*/15 * * * * ${BIOUSER} cd /home/${BIOUSER}/NFS/ && /usr/bin/flock -w 10 /var/lock/bio-class/startNFS ./startNFS.sh -m cron >/dev/null 2>&1" > /etc/cron.d/checkNFS
  cd "$SCRIPTDIR"
  mkdir -p /home/"${BIOUSER}"/NFS/conf
  cp ${SCRIPTDIR}/startNFS.sh /home/"${BIOUSER}"/NFS
  cp ${CONF_DIR}/.conf /home/"${BIOUSER}"/NFS/conf
  chown "${BIOUSER}": /home/"${BIOUSER}"/NFS -R
  chmod +x /home/"${BIOUSER}"/NFS/startNFS.sh
  # Group for bioconductor
  groupadd bioconductor
  usermod -a -G bioconductor "${BIOUSER}"
  groups "${BIOUSER}"

  # RStudio Server: Running with a Proxy
  mkdir -p /home/"${BIOUSER}"/HTTPS/conf
  cp ${SCRIPTDIR}/startHTTPS.sh /home/"${BIOUSER}"/HTTPS
  chown "${BIOUSER}": /home/"${BIOUSER}"/HTTPS -R
  chmod +x /home/"${BIOUSER}"/HTTPS/startHTTPS.sh
  for file in ${CONF_DIR}/.conf ${CONF_DIR}/nginx.conf ${CONF_DIR}/nginx.conf.clean ${CONF_DIR}/rserver.conf.clean ; do \
  cp $file /home/"${BIOUSER}"/HTTPS/conf ; done
  chmod 644 /home/"${BIOUSER}"/HTTPS/conf/* ; chown root: /home/"${BIOUSER}"/HTTPS/conf/*
fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "base" ]]; then
  update_sources ; apt-get -y install nginx ;
  # certbot
  echo "deb http://deb.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/backports.list
  update_sources ; apt-get -y install certbot python-certbot-nginx -t stretch-backports

  cp ${CONF_DIR}/index.nginx-debian.html /var/www/html/
  if [[ -f /var/www/html/index.nginx-debian.html ]];then
    chown root: /var/www/html/index.nginx-debian.html
    chmod 644 /var/www/html/index.nginx-debian.html
  fi
fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "post" ]];then
  # Cron for backup
  echo -e "* 1,13 * * * ${BIOUSER} public_ipv4=\$(curl -s http://169.254.169.254/2009-04-04/meta-data/public-ipv4 2>/dev/null | grep -E -o \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\");nginxconf=\$(grep cert.pem /etc/nginx/nginx.conf) ;[ -n \"\$public_ipv4\" ] && [ -n \"\$nginxconf\" ] && [ -d "${NFS_HOME_PERSISTENT}/${BIOUSER}/${NFS_STORAGE_BACKUP_HTTPS_DIR}" ] && cd /home/${BIOUSER}/HTTPS/ && /usr/bin/flock -w 10 /var/lock/bio-class/startHTTPS ./startHTTPS.sh -m backup >/dev/null 2>&1" > /etc/cron.d/backupHTTPS
fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "post" ]];then
  # Set permissions for "$BIOUSER" account
  for item in /opt/${name}/ $TMP_DIR /usr/lib/R/ /usr/share/R/ /usr/local/lib/R/site-library; do
  chmod g+s "$item"; setfacl -dR -m g:"$BIOUSER":rwx "$item" ; setfacl -dR -m u:"$BIOUSER":rwx "$item" ;
  setfacl -R -m u:"$BIOUSER":rwx "$item" ;setfacl -R -m g:"$BIOUSER":rwx "$item" ;  done
  # Export PATH, ll alias
  for FILE in /home/debian/.bashrc /home/"$BIOUSER"/.bashrc /root/.bashrc ; do \
    sed -i 's/#alias ll=\x27ls -l\x27/alias ll=\x27ls -laF\x27/g' "$FILE" ;
    #TMP_PATH=$(cat "${PATH_FILE}" | tr -d '\n') ; echo "export PATH=${PATH}${TMP_PATH}" >> "$FILE" ;

    # Export PATH, ll alias, load chanels if not loaded
    echo "# In each new bash session, before using conda, set the PATH" >> "$FILE" ;
    if [[ "$MODE" == "all" ]];then
      echo "export PATH=${PATH}" >> "$FILE" ;
    elif [[ "$MODE" == "post" ]];then
      TMP_PATH=$(cat "${PATH_FILE}" | tr -d '\n') ; echo "export PATH=${PATH}${TMP_PATH}" >> "$FILE" ;
    fi
    sed -i 's/#alias ll=\x27ls -l\x27/alias ll=\x27ls -laF\x27/g' "$FILE" ;
    echo "# Run the activation scripts of your conda packages" >> "$FILE";
    echo "# source ${INSTALL_DIR}/miniconda/bin/activate" >> "$FILE";
    echo "# Add channels directly instead of using conda config --add channels <channel>
echo \"channels:
  - conda-forge
  - bioconda
  - defaults\" > $(dirname $FILE)/.condarc" >> "$FILE";
    echo -e "alias startConda='source ${INSTALL_DIR}/miniconda/bin/activate'" >> "$FILE";
    echo -e "alias stopConda='conda deactivate'" >> "$FILE";
 
  done ;

  echo -e "alias startNFS='cd /home/${BIOUSER}/NFS && ./startNFS.sh -m keytab'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias stopNFS='cd /home/${BIOUSER}/NFS && ./startNFS.sh -m destroy'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias statusNFS='cd /home/${BIOUSER}/NFS && ./startNFS.sh -m status'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias startHTTPS='cd /home/${BIOUSER}/HTTPS && ./startHTTPS.sh -m https'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias stopHTTPS='cd /home/${BIOUSER}/HTTPS && ./startHTTPS.sh -m http'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias statusHTTPS='cd /home/${BIOUSER}/HTTPS && ./startHTTPS.sh -m status'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias startHTTPSlocalCrt='cd /home/${BIOUSER}/HTTPS && ./startHTTPS.sh -m localcrt'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias backup2NFS='cd /home/${BIOUSER}/ && rsync -av --exclude rstudio-pass --no-owner --no-group --no-perms --omit-dir-times --progress ~/  ${NFS_HOME_PERSISTENT}/${BIOUSER}'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias restoreFromNFS='cd /home/${BIOUSER}/ && rsync -av --exclude rstudio-pass --no-owner --no-group --no-perms --omit-dir-times --progress ${NFS_HOME_PERSISTENT}/${BIOUSER}/ ~/'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias statusBIOSW='/home/debian/bio-class/install/install_software_check.sh -m status'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias updateBIOSW='/home/debian/bio-class/install/install_software_check.sh -m updateBIOSW'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias updateOS='/home/debian/bio-class/install/install_software_check.sh -m updateOS'" >> /home/"$BIOUSER"/.bashrc;
  echo -e "alias updateREPO='/home/debian/bio-class/install/install_software_check.sh -m updateREPO'" >> /home/"$BIOUSER"/.bashrc;

  # virtualenv - E06
  su - "${BIOUSER}" -c "/usr/bin/python3.5 -m pip install --upgrade --user virtualenv"
fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "base" ]]; then
  # Disable login using password
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config ;
  # Enable only strong ciphers and MACs algorithms
  sed -i 's/#   Ciphers.*/Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr/g' /etc/ssh/sshd_config ;
  sed -i '/^Ciphers .*/a MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com' /etc/ssh/sshd_config ;
  sed -i '/^MACs .*/a HostKeyAlgorithms ssh-rsa,rsa-sha2-512,rsa-sha2-512,rsa-sha2-512' /etc/ssh/sshd_config ;
  # Other sshd_setting
  sed -i 's/#SyslogFacility .*/SyslogFacility AUTHPRIV/g' /etc/ssh/sshd_config ;
  sed -i 's/#PermitRootLogin .*/PermitRootLogin no/g' /etc/ssh/sshd_config ;
  sed -i 's/AcceptEnv LANG LC_\*/AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES/g' /etc/ssh/sshd_config ;
  sed -i '/^AcceptEnv LANG .*/a AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT' /etc/ssh/sshd_config ;
  sed -i '/^AcceptEnv LC_PAPER .*/a AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE' /etc/ssh/sshd_config ;
  sed -i '/^AcceptEnv LC_IDENTIFICATION .*/a AcceptEnv XMODIFIERS' /etc/ssh/sshd_config ;
  sed -i '/^AcceptEnv XMODIFIERS/a AcceptEnv GIT_*' /etc/ssh/sshd_config ;

  #  SSH config
  sed -i 's/#   Ciphers.*/Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr/g' /etc/ssh/ssh_config ;
  sed -i '/^Ciphers .*/a MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com' /etc/ssh/ssh_config ;
  sed -i '/^MACs .*/a HostKeyAlgorithms ssh-rsa,rsa-sha2-512,rsa-sha2-512,rsa-sha2-512' /etc/ssh/ssh_config ;
  sed -i 's/#   ForwardX11Trusted yes/ForwardX11Trusted yes/g' /etc/ssh/ssh_config ;
fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "base" ]] || [[ "$MODE" == "post" ]]; then
  # Diffie-Hellman, ssh -Q kex, ssh -Q cipher | sort -u
  mkdir -p /etc/ssl/private
  chmod 710 /etc/ssl/private
  if [[ "$MODE" == "all" ]] || [[ "$MODE" == "post" ]]; then
    if [[ -f  /root/.rnd ]];then
      rm /root/.rnd
    fi
    touch /root/.rnd
    chown root: /root/.rnd
    export RANDFILE=/root/.rnd
  fi
  cd /etc/ssl/private &&  openssl dhparam -out dhparams.pem 2048; chmod 600 dhparams.pem

  /etc/init.d/ssh reload
  cd "$SCRIPTDIR"
fi

# Set ssh key for debain back to him
if [[ -n "$INDEVELOP" ]];then
  chown debian: /home/debian/.ssh/authorized_keys
fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "post" ]];then
  # Copy ssh from debian account, .vimrc 
  mkdir -p /home/"$BIOUSER"/.ssh; cd /home/"$BIOUSER"; cp /home/debian/.ssh/authorized_keys .ssh/; chmod 700 .ssh; chmod 600 /home/"$BIOUSER"/.ssh/authorized_keys; chown "$BIOUSER": /home/"$BIOUSER"/.ssh -R
  for FILE in /home/debian/.vimrc /home/"$BIOUSER"/.vimrc /root/.vimrc ; do echo "color murphy" >> "$FILE" ; echo "set mouse-=a" > ~/.vimrc ; done
  # Set motd Rstudio URL and show "$BIOUSER" password
  tmp_text=
  if [[ -n "$BIOSW_AGE" ]];then
    tmp_text="Analysis of gene expression"
  fi
  if [[ -n "$BIOSW_GAA" ]];then
    if [[ -n "$tmp_text" ]];then
      tmp_text+=", Genomics: algorithms and analysis"
    else
      tmp_text="Genomics: algorithms and analysis"
    fi
  fi
  if [[ -z "$tmp_text" ]];then
    tmp_text="BIOCONDUCTOR"
  fi
  # Message change if student account instead of real Einfra account
  tmp_text_student=
  if [[ "$BIOUSER" == "student" ]];then
    tmp_text_student="\n\nFor account student NFS mount won't work! To access NFS storage rather create new instance using your Einfra login!"
  fi
  floating_ip_text="http://<Openstack-Floating-IP>:8787"
  if [[ -n "$public_ipv4" ]];then
    public_ipv4_name=$(nslookup "$public_ipv4" | grep name | sed -rn "s/.*name = (.*)/\1/p" | sed "s/\.$//g")
    floating_ip_text="https://${public_ipv4_name}"
  fi
  echo -e "\n\n"$tmp_text"\n\nRstudio available at "$floating_ip_text" using account "$BIOUSER" and password $(cat /home/"$BIOUSER"/rstudio-pass)\n\nFind out the current Rstudio URL using command \"statusHTTPS\"\n\nTo mount NFS storage execute \"startNFS\" using your MetaCentrum Cloud password, to umount \"stopNFS\" and to check current state \"statusNFS\"\n * After instance reboot execute \"startNFS\" again"$tmp_text_student"\n\nTo switch Rstudio from HTTP to HTTPS, run one of the following commands of your choice:\n * \"startHTTPS\" -  get a certificate from  Let’s Encrypt\n * \"startHTTPSlocalCrt\" - get self-signed certificate with OpenSSL (For Experienced Users Only)\n   (In Browser Allow Self Signed Certificate: button Advanced -> Add Exception / Accept the Risk and Continue)\n * To switch back to unsecured HTTP execute command \"stopHTTPS\"\n * Find out the current Rstudio URL using command \"statusHTTPS\"\n\nTo activate conda execute command \"startConda\", to deactivete \"stopConda\"\n\nTo backup you home directory with lesson results to NFS execute \"backup2NFS\", to restore \"restoreFromNFS\"\n   (Nothing is deleted on the other side, add --delete in .bashrc alias if you wish to perform delete during rsync (For Experienced Users Only))\n\n" > /etc/motd


fi

if [[ "$MODE" == "all" ]] || [[ "$MODE" == "base" ]];then
  find "$TMP_DIR" -maxdepth 1 -type f > /home/debian/installed_files.txt
fi

# Clean up: Remove install dir
if ([[ -z "$INDEVELOP" ]] && [[ "$MODE" == "all" ]])|| [[ "$MODE" == "base" ]]; then
  rm -rf "${TMP_DIR}";
fi


# "Finished Custom Script"
exit 0
