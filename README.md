# Bio-class

Repository for building virtual classroom for biology students using [OpenStack](https://cloud.muni.cz/)

* Analysis of gene expression class tought at Institute of Molecular Genetics of the ASCR, v. v. i.
* Genomics: algorithms and analysis class tought at Institute of Molecular Genetics of the ASCR, v. v. i.

## Image with installed software
Use prepared image containing all required software is a preferred way. Some of steps below are covered by [fronted application](http://bio-portal.metacentrum.cz) with guide available [here](doc/user/frontend.md). In case of manual action, please [proceed with all required steps individually](./doc/user/launch-in-personal-project.md).

### SSH Access
Connect to the VM using your [login](https://cloud.gitlab-pages.ics.muni.cz/documentation/register/), [id_rsa key registered in Openstack](https://cloud.gitlab-pages.ics.muni.cz/documentation/quick-start/#create-key-pair) or see [Key pair check](./doc/user/launch-in-personal-project.md#key-pair) and [Floating IP in Openstack](https://cloud.gitlab-pages.ics.muni.cz/documentation/quick-start/#associate-floating-ip) or see [Floating IP check](./doc/user/launch-in-personal-project.md#floating-ip):
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
    * To backup you home directory with lesson results to NFS execute `backup2NFS`, to restore `restoreFromNFS`
      * (Nothing is deleted on the other side, add --delete in .bashrc alias if you wish to perform delete during rsync (For Experienced Users Only))
    * After instance reboot execute `startNFS` again

* Swith to HTTPS running command `startHTTPS`
    * By default Rstudio uses HTTP (unsecured) and is accesible on port 8787
    * Find out the current Rstudio URL using command `statusHTTPS`
    * In case of issues try to execute `stopHTTPS` and `startHTTPS` again
    * In case of issue obtaing Let's Encrypt certificate using `startHTTPS` try `startHTTPSlocalCrt` (For Experienced Users Only)
      ([In browser you need to accept self-signed certificate](doc/img/browser_exception.png))
    * To switch back to HTTP only use `stopHTTPS`
    * Find out the current Rstudio URL using command `statusHTTPS`

* Update R/Bioconductor packages
    * Execute `statusBIOSW` to see installed/out-of-date packages
    * Open Tmux session using `tmux` or attach to the existing Tmux session by `tmux attach`. Tmux can prevent updates break if your local computer for example loose connection. Another example is executing bash commands with long run time when Tmux can save your time.
    * Execute `updateBIOSW` to update installed R/Bioconductor packages
    * You can leave Tmux session now `Ctl+B+D` (not closing the session using `Ctrl+D`), because commands can continue in Tmux without your SSH connection active
    * Check if updates has finished by attaching Tmux session using `tmux attach`, check output and close Tmux session using `Ctrl+D` if updates has finished already


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

