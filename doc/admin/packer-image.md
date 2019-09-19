# Create the Bioconductor image

There are two possibilities to build image directly from your [local machine](#initialize-image-directly-from-your-local-machine) or using [Tmux on VM](#initialize-image-using-prepared-vm-with-packer-installed).

Image producer should [set image status to shared](#share-an-image), otherwise not shown in customer image list. If status set to public, then share/accept action is not required.

## Initialize image directly from your Local machine

### Install Openstack CLI and Packer

[OpenSstack CLI](https://cloud.gitlab-pages.ics.muni.cz/documentation/cli/) and [Parser](https://www.packer.io/docs/builders/openstack.html) are required to build an image.

### Packer version

```
packer --version
1.4.2
```

### SSH key for provisioning

Create SSH key without passphrase:
```
ssh-keygen -b 2048 -t rsa -f ~/.ssh/packer_id_rsa -N ""
```

### Add the key to Openstack

```
openstack keypair create --public-key ~/.ssh/packer_id_rsa.pub packer-key
```

### Prepare Template

* Clone project and change directory to ./install
* You can use already downloaded installation files in directory ./install/files instead of downloading them during cloud init again
* Use OpenStack CLI to obtain required data to full fill packer_template.JSON
    * ssh_keypair_name - string from Instances -> Key Pairs `openstack keypair list`
    * ssh_private_key_file - relative path to the private key which mathes public key from ssh_keypair_name
    * floating_ip address - ID of Public IP address from Network -> Floating IPs `openstack floating ip list`
    * ssh_username account - login used for SSH provisioning (for Debian typically debian)
    * source_image - source image ID `openstack image list`
    * flavor - Flavor ID `openstack flavor list`

* After succesfull build installation logs are available in local directory ./install/logs

### Remove known_hosts record from previous build before connecting

```
ssh-keygen -f "/root/.ssh/known_hosts" -R "<Floating IP>"
```

### Build an Image

Prepared template is used to build VM. Provisioning is used to set all required settings.
Debug option is used in this example:
```
### Verify syntax
packer validate packer_template.JSON
# Build using debug parameter
packer build -debug packer_template.JSON
```

### Rename Previous Image

```
openstack image set --name <imageName> <imageID>
```

### Delete an Image

```
# Check images to delete
openstack image list | grep bioconductor
| b97137f6-7b35-477d-9fa0-3f84031803b9 | debian-9-x86_64_bioconductor                | active |
# Delete selected image using ID
openstack image delete b97137f6-7b35-477d-9fa0-3f84031803b9
```

## Initialize Image using prepared VM with Packer installed

* Check Rules in Security Group if containing "Permit SSH". Add new rule for SSH if missing:
```
ROUTER_ID=$(openstack router list -c ID -f value);
ROUTER_IP=$(openstack router show -f value -c external_gateway_info $ROUTER_ID |tr -d '"'| sed -rn 's/.*ip_address: ([0-9\.]+).*/\1/p');
SEC_GROUP=$(openstack security group list -c ID -f value);
openstack security group rule create --description "Permit SSH" --remote-ip ${ROUTER_IP}/32 --protocol tcp --dst-port 22 --ingress $SEC_GROUP
```

* Login to prepared VM builded using template [packer_template.JSON.sample](./../../packer_master/packer_template.JSON.sample)
* Open Tmux session `tmux` or attach to it `tmux attach`
* Check used ID inside the template packer_template.JSON
* If private repository, then check private/public keys
* Start building image: `sleep 80; packer build packer_template.JSON`
* Leave Tmux session (Ctrl+B D), not closing the session using Ctrl+D
* Logout from VM
* Disassociate a Floating IP from an instance


## Share an Image

### Image Producer

* Get ID of Image to Share
```
openstack image list
```

* Share an Image
```
openstack image set --shared <image ID>
openstack image add project <image ID> <project ID to share image to>
```

* List of Shared Images
```
openstack image list --shared
```

* Unshare an Image
```
openstack image remove project <image ID> <project ID to unshare image from>
```

### Image Consumer

* Accept a Shared Image
```
openstack image member list <image ID>
openstack image set --accept <image ID>
```

