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

echo "Installed software check"

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

SW_NAME="BiocManager"
command_output=$(Rscript -e "BiocManager::version()")
command_status="$?"
function_echo_output

SW_NAME="conda"
command_output=$(conda --version)
command_status="$?"
function_echo_output

# Checks

exit 0