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

# R library
for package in rlist ggthemes heatmaply ggpubr; do Rscript -e "install.packages(\"${package}\")"; done

# Patch

exit 0
