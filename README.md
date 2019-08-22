# Bio-class

Repository for building virtual classroom for biology students using [OpenStack](https://cloud.muni.cz/)

* Analysis of gene expression class tought at Institute of Molecular Genetics of the ASCR, v. v. i.
* Genomics: algorithms and analysis class tought at Institute of Molecular Genetics of the ASCR, v. v. i.

## Image with installed software
Prefered way is to use prepared image containing all required software. Some of steps below are covered by fronted application. In case of manual action, please check all required steps individually.

### SSH Access
Connect to the VM using your [login](https://cloud.gitlab-pages.ics.muni.cz/documentation/register/), [id_rsa key registered in Openstack](https://cloud.gitlab-pages.ics.muni.cz/documentation/quick-start/#create-key-pair) and [Floating IP](https://cloud.gitlab-pages.ics.muni.cz/documentation/quick-start/#associate-floating-ip):
```
ssh -A -X -i ~/.ssh/id_rsa login@<Floating IP>
```
```
-A      Enables forwarding of the authentication agent connection.
-X      Enables X11 forwarding.
```

Password is located at file `/home/<login>/rstudio-pass`.

All required steps are listed in MOTD after login.

### NFS and HTTPS
There are only two steps to proceed with after instance launch using prepared image:
* Start NFS running command `startNFS`
    * Project directory is located under /storage/projects/bioconductor/ on frontend and exported as /data/ on VM
    * There are 2 directories present:
      * persistent - contains home directories for each BIO class user
      * shared - contains shared data for BIO class
    * In case of issues try to execute `stopNFS` and `startNFS` again

* Swith to HTTPS running command `startHTTPS` or `startHTTPSlocalCrt` ([In browser you need to accept self-signed certificate](doc/img/browser_exception.png))
    * By default Rstudio uses HTTP (unsecured) and is accesible on port 8787
    * Find out the current Rstudio URL using command `statusHTTPS`
    * In case of issues try to execute `stopHTTPS` and `startHTTPS` again or using `startHTTPSlocalCrt`

### Tips
If you use Shiny library then please [confirm pop-ups](doc/img/shiny_pop-ups.png).

In [Security Group add rules](https://cloud.gitlab-pages.ics.muni.cz/documentation/quick-start/#update-security-group) add rules:
* For SSH to `<your computer private IPv4 address>/32` or allow it from anywhere `0.0.0.0/0`
* HTTP and HTTPS to allow Ingress availability from anywhere `0.0.0.0/0` (required for generate certificate using port 80)
```
Ingress         IPv4    TCP     22 (SSH)        <your private IPv4 address>/32       -       -
Ingress         IPv4    TCP     80 (HTTP)       0.0.0.0/0       -       -
Ingress         IPv4    TCP     443 (HTTPS)     0.0.0.0/0       -       -
Egress	        IPv4 	Any 	Any 	0.0.0.0/0
```

## Admin section
* For testing purposes in case of modifications you may [install all required software directly during VM initialize](doc/admin/test-in-personal-project.md) (time consuming).
* Packer Master VM for buiding images is described [here](doc/admin/packer-image.md#initialize-image-using-prepared-vm-with-packer-installed).
* Note [admin documentation](./doc/admin/).

