# Install all required software directly during VM cloud init (time consuming)

Using prepared image is a preferred way, but for testing purposes you may try to initialize VM in personal project.

* Follow the instructions [Quick Start](https://cloud.gitlab-pages.ics.muni.cz/documentation/quick-start/)
* Obtain Floating IP, update Security Group and so on
* Launch instance
    * Insert name of your instance
    * Select Boot source Image and select Yes for Delete Volume on Instance delete
    * Select Flavor
    * Select Key pair
    * In Configuration insert code from [cloud-init-custom-script.sh](./../../install/cloud-init-custom-script.sh)
    * In Metada insert variables:
        * Bioclass_user containg your login
        * Bioclass_email containing your email
    * Proceed with Launch button
* Login using your SSH key as selected in Key pair above
    * To access NFS use startNFS after login (METACENTRUM password required)
        * To stop NFS use stopNFS
    * To switch HTTP to HTTPS, run one of the following commands of your choice:
        * Execute startHTTPS after starting NFS (NFS is required)
        * Execute startHTTPSlocalCrt - get self-signed certificate with OpenSSL
          (In Browser Allow Self Signed Certificate: button Advanced -> Add Exception / Accept the Risk and Continue)
        * To swith back to HTTP only use stopHTTPS
