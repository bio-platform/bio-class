# Github private repo

Private repository is available only for project collaborators or deploy key if attached:

* Generate SSH key pair without password
```
ssh-keygen -t rsa -b 4096 -C "{email}"
```
* Set variable PRIVATE_REPO to true in <packer|cloud>-init-custom-script.sh and update repo URL
* Add public key to the private repository https://github.com/{user}/{repo}/settings/keys and allow write access if really needed (Read only is fully sufficient here)

