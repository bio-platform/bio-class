# Bio-class

Repository for building virtual classroom for biology students using [OpenStack](https://cloud.muni.cz/)

* Analysis of gene expression class tought at Institute of Molecular Genetics of the ASCR, v. v. i.
* Genomics: algorithms and analysis class tought at Institute of Molecular Genetics of the ASCR, v. v.

## Image with installed software
Prefered way is to use prepared image containg all required software. There are only two steps to proceed with after instance launch using prepared image:
* Start NFS running command startNFS
    * Project directory is located under /storage/projects/bioconductor/ on frontend and exported as /data/ on VM.
* Swith to HTTPS running command startHTTPS
    * By default Rstudio uses HTTP only.

## Admin section
For testing purposes in case of modifications you may install all required software directly during VM initialize (time consuming). Note [admin documentation](./doc/admin/).


