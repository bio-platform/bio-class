# Launch New Instance in Personal Project 

Using prepared image is a preferred way. Frontend appliacation is prepared to fully cover instance launch steps automatically on background. Proceed with guide below if manual instance launch needed.

* Follow the instructions [Quick Start](https://cloud.gitlab-pages.ics.muni.cz/documentation/quick-start/)
  * Obtain Floating IP, update Security Group and so on
* Launch instance
    * Open Project -> Compute -> Instances and use button **Launch Instance**
    ![Launch instance](./../img/instance_launch.png)
    * Insert Instance Name, Description
    ![Insert name of your instance](./../img/instance_launch_details.png)
    * Source:
      * Select Boot source: **Image**
      * Select **Yes** for Delete Volume on Instance delete
      * Use Up Arrow to select image with **bioconductor software**
    ![Select Boot source Image](./../img/instance_launch_source.png)
    * Select Flavor *2 CPU* and *16GB RAM*
    ![Select Flavor](./../img/instance_launch_flavor.png)
    * Key pair
      * **If public key imported already**, add existing key to the instance and continue using button **Next**
      * **Import Key Pair** if existing SSH key on your local computer, but not listed as available, then import public key using button **Import Key**
        * Insert Key Pair Name
        * Select SSH key for Key Type
        * Load Public Key from a file or copy/paste public key content in the field
        * Add key and continue using button **Next**
      * **Create key Pair** if any public key not available
        * Use button **Create Key Pair**
        * Insert Key Pair Name
        * Select SSH key for Key Type
        * Use button **Create KeyPair**
        * Copy Private Key to Clipboard and save it to the ~/.ssh/id_rsa on your local computer
        * Confirm using button **Done**
        * Now the public key is available down on the page. Use arrow before key name to show public part. Copy this public key to the file ~/.ssh/id_rsa.pub on your local computer
        * Add key and continue using button **Next**
        * Check Access Privileges on .ssh Folder using commands `chmod 700 .ssh/`, `chmod 644 .ssh/id_rsa.pub` and `chmod 600 .ssh/id_rsa`
    ![Select Key pair](./../img/instance_launch_key_pair.png)
    * In Configuration insert code from [cloud-init-bioconductor-image.sh](./../../install/cloud-init-bioconductor-image.sh) or use **Browse** button to search in clonned repository `git clone https://github.com/bio-platform/bio-class.git`.
    
    ![Metadata](./../img/instance_launch_configuration.png)
    * In Metada insert variables:
        * *Bioclass_user* containg your login
        * *Bioclass_email* containing your email
        * Proceed with **Launch button**
    ![Metadata](./../img/instance_launch_metadata.png)
* Wait until instance initialization finished and Associate Floating IP
  * All required settings are executed during instance boot
  * Use button **Associate Floating IP**
  * Select available floating IP and confirm using button **Associate**
    ![Associate Floating IP](./../img/instance_associate_ip.png)
* Login using your [SSH key as selected in Key pair above and Floating IP](./../../README.md#ssh-access)
  * Set up [NFS and HTTPS](./../../README.md#nfs-and-https)
