<!-- (C) Copyright 2024 Hewlett Packard Enterprise Development LP -->

Ubuntu/Debian Bring Your Own Image (BYOI) for HPE Private Cloud Enterprise - Bare Metal
=============================

* [Overview](#overview)
* [Example of manual build for reference](#example-of-manual-build-for-reference)
* [Building Ubuntu or Debian image](#building-ubuntu-or-debian-image)
  *   [Setup Linux system for imaging build](#setup-linux-system-for-imaging-build)
  *   [Downloading recipe repo from GitHub](#downloading-recipe-repo-from-github)
  *   [Downloading Ubuntu or Debian ISO file](#downloading-ubuntu-or-debian-iso-file)
  *   [Building the Bare Metal Ubuntu or Debian image and service](#building-the-bare-metal-ubuntu-or-debian-image-and-service)
* [Customizing Ubuntu or Debian image](#customizing-ubuntu-or-debian-image)
  *   [Modifying the way the image is built](#modifying-the-way-the-image-is-built)
* [Using the Ubuntu or Debian service and image](#using-the-ubuntu-or-debian-service-and-image)
  *   [Adding Ubuntu or Debian service to Bare Metal portal](#adding-ubuntu-or-debian-service-to-bare-metal-portal)
  *   [Creating a Ubuntu or Debian Host with Ubuntu or Debian Service](#creating-a-ubuntu-or-debian-host-with-ubuntu-or-debian-service)
  *   [Triage of image deployment problems](#triage-of-image-deployment-problems)
  *   [Known Observations and Limitations](#known-observations-and-limitations)
  *   [Ubuntu or Debian License](#ubuntu-or-debian-license)
  *   [Storage Volumes iSCSI and FC](#storage-volumes-iscsi-and-fc)


----------------------------------

# Overview

This GitHub repository contains the script files, template files, and documentation for creating an Ubuntu/Debian service for HPE Bare Metal from an Ubuntu/Debian install .ISO file.  By building a custom image via this process, you can control the exact version of Ubuntu/Debian that is used and modify how Ubuntu/Debian is installed via a DebianInstaller Preseed file.  Once the build is done, you can add your new service to the HPE Bare Metal Portal and deploy a host with that new image.

# Example of manual build for reference

Workflow for Building Image:

![image](https://github.com/hpe-hcss/bmaas-byoi-debian-build/assets/90067804/e7145718-9099-4f8e-a776-a1f5f89c28c9)

**Prerequisites:**
```
1. You will need a Web Server with HTTPS support for storage of the HPE Base Metal images.
2. The Web Server is anything that:
    A. you have the ability to upload large OS image (.iso) to, and
    B. is on a network that will be reachable from the HPE On-Premises Controller.
       When an OS image service (.yml) is used to create an HPE Bare Metal Host, the HPE Bare Metal
       OS image (.iso) will be downloaded via the `secure_url` mentioned in the service file (.yml).
3. IMPORTANT:
   The test `hpe-test-service-image.sh` script is to verify the HPE Bare Metal OS image (.iso).
   To run this test, edit the file `./hpe-build-image-and-service.sh` to set the required
   Web Server-related parameters, listed below:
      +----------------------------------------------------------------------------
      | +--------------------------------------------------------------------------
      | | File `./hpe-build-image-and-service.sh`
      | |   <1> WEB_SERVER_IP: IP address of web server to transfer ISO to (via SSH)
      | |       Example: WEB_SERVER_IP="10.152.3.96"
      | |   <2> REMOTE_PATH:   Path on web server to copy files to
      | |       Example: REMOTE_PATH="/var/www/images/"
      | |   <3> SSH_USER:      Username for SSH transfer
      | |       Example: SSH_USER_NAME="root"
      | | Note: Add your Linux test machine's SSH key to the Web Server
      | +--------------------------------------------------------------------------
      +----------------------------------------------------------------------------
   In this document, for the manual build example:
   A. a local Web Server "https://10.152.3.96" is used for the storage of OS images (.iso).
   B. we are assuming that the HPE Bare Metal OS images will be kept in: https://10.152.3.96/images/<.tar>
4. Linux machine for building OS image:
   A. Image building has been successfully tested with the following list of Ubuntu OS and its LTS versions:
      Ubuntu 20.04.6 LTS (focal)
      Ubuntu 22.04.5 LTS (jammy)
      Ubuntu 24.04.1 LTS (noble)
   B. Install supporting tools (git, xorriso, isomd5sum, isolinux, aptly, sudo, and wget)
```

Step 1. Source code readiness

A. Clone the GitHub Repo `hpegl-metal-os-debian-iso`
```
git clone https://github.com/HewlettPackard/hpegl-metal-os-debian-iso.git
```
B. Change the directory to `hpegl-metal-os-debian-iso`

Step 2. Download the Ubuntu/Debian .ISO image to your local build environment via what ever method you prefer (Web Browser, etc)

For example, we will assume that you have downloaded debian-12.5.0-amd64-DVD-1.iso into the local directory.

Step 3. Run the script `hpe-build-image-and-service.sh` to generate an output Bare Metal image bundle .tar as well as Bare Metal Service .yml:

Example: Run the build including artifact verification
```
./hpe-build-image-and-service.sh \
  -v 12.5.0 \
  -n Debian \
  -p https://<web-server-address> \
  -r qPassw0rd \
  -i debian-12.5.0-amd64-DVD-1.iso \
  -o debian.tar \
  -s debian.yml
```

Example: Run the build excluding artifact verification
```
./hpe-build-image-and-service.sh \
  -v 12.5.0 \
  -n Debian \
  -p https://<web-server-address> \
  -r qPassw0rd \
  -i debian-12.5.0-amd64-DVD-1.iso \
  -o debian.tar \
  -s debian.yml \
  -x true
```

Step 4. Copy the output Bare Metal image bundle .tar to the Web Server.

Step 5. Add the Bare Metal service .yml file to the appropriate Bare Metal portal.

To add the Bare Metal service .yml file, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant". Select the Dashboard tile "Metal Consumption" and click on the tab "OS/application images".
Click on the button "Add OS/application image" to upload this service .yml file.

Step 6. Create a new Bare Metal host using this OS image service.

To create a new Bare Metal host, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
Select the Dashboard tile "Metal Consumption" and click on the tab "Compute groups". Further, create a host using the following steps:
a. First create a Compute Group by clicking the button "Create compute group" and fill in the details.
b. Create a Compute Instance by clicking the button "Create compute instance" and fill in the details.


# Building Ubuntu or Debian image

These are the high-level steps required to generate the Bare Metal Ubuntu/Debian service:
* Set up a Linux system with 20-40GB of free file system space for the build
* Set up a local file transfer/storage tool (E.g. **Local Web Server with HTTPS support**) that Bare Metal can reach over the network.
  * For **unsecured Web Server access**, please refer to the [Hosting](Hosting.md) for additional requirements, listed below:
    *  A. **HTTPS** with certificates signed by **publicly trusted Certificate authority**, and
    *  B. **Skip** the host’s **SSL certificate verification**.
  * For **Web Server running behind the Firewall**, the Web Server IP address and Port has to be whitelisted in the **rules** and **Proxy**.
* Install Git Version Control (git) and other supporting tools (xorriso, isomd5sum, isolinux, aptly, sudo, and wget)
* Downloading recipe repo from GitHub
* Download a Ubuntu/Debian .ISO file
* Build the Bare Metal Ubuntu/Debian image/service

These are the high-level steps required to use this built Bare Metal Ubuntu/Debian service/image on Bare Metal:
* Copy the built Bare Metal Ubuntu/Debian .ISO image to your web server
* Add the Bare Metal Ubuntu/Debian .YML service file to the appropriate Bare Metal portal
* In Bare Metal, create a host using this Ubuntu/Debian image service

## Setup Linux system for imaging build

These instructions and scripts are designed to run on a Linux system.
Further, these instructions were developed and tested on a Ubuntu 20.04 VM, but they should work on other distros/versions.
The Linux host will need to have the following packages installed for these scripts to run correctly:

Packages      | Description
------------- | ---------------------
git           | a source code management tool.
xorriso       | a RockRidge filesystem manipulator, libburnia project.
isomd5sum     | utilities for working with md5sum implanted in ISO images.
isolinux      | to make a bootable disk image.
aptly         | a ubuntu/debian repository management tool.
wget          | The non-interactive network downloader.
sudo          | execute a command as another user.

On Ubuntu 20.04 VM, the necessary packages can be installed with:

```
sudo apt install -y git xorriso isomd5sum isolinux aptly wget sudo
```

> **_NOTE:_**  You must also have sudo (superuser do) capability so that you can mount the Ubuntu/Debian ISO
> and copy the files from it to generate a new Ubuntu/Debian .ISO file for Bare Metal.

The resulting Ubuntu/Debian .ISO image file from the build, needs to be uploaded to a web server that
the HPE On-Premises Controller can access over the network.  More about this later.

## Downloading recipe repo from GitHub

Once you have an appropriate Linux environment setup, then download this recipe from GitHub
for building the HPE Bare Metal Ubuntu/Debian by:

```
git clone https://github.com/HewlettPackard/hpegl-metal-os-debian-iso.git
```

## Downloading Ubuntu or Debian .ISO file

Next, you will need to manually download the appropriate Ubuntu/Debian .ISO onto the Linux system.
This Ubuntu/Debian recipe has been successfully tested with the following list of Ubuntu/Debian distributions and its derivatives:
* Debian 12.5

> **_NOTE:_**  This recipe should work on other Ubuntu/Debian or Debian-based distros that support the same DebianInstaller Preseed and .ISO construction as recent version of Ubuntu/Debian.

## Building the Bare Metal Ubuntu or Debian image and service

At this point, you should have a Linux system with:
* a copy of this repo
* a standard Ubuntu/Debian .ISO file

We are almost ready to do the build, but we need to know something about your environment.
When the build is done, it will generate two files:
* a Bare Metal modified Ubuntu/Debian .ISO file that needs to be hosted on a web server.
  It is assumed that you have (or can set up) a local web server that Bare Metal can reach over the network.
  You will also need login credentials on this Web Server so that you can upload the files.
* a Bare Metal service .YML file that will be used to add the Ubuntu/Debian service to the portal.
  This .YML file will have a URL to the Bare Metal modified Ubuntu/Debian .ISO file on the web server.

The build needs to know what URL can be used to download the Bare Metal modified Ubuntu/Debian .ISO file.
We assume that the URL can be broken into 2 parts: \<image-url-prefix\>/\<bare-metal-custom-bebian-iso\>

If the image URL can not be constructed with this simple mechanism, then you probably need to
customize this script for a more complex URL construction.

So you can run the build with the following command line parameters:

```
./hpe-build-image-and-service.sh \
    -i <distro-iso-filename> \
    -v <distro-version-number> \
    -n <distro-version-name> \
    -r <distro-rootpw> \
    -p <image-url-prefix> \
    -o <distro-tar-file> \
    -s <distro-service-file> \
    -x <skip-test>
```

When a Ubuntu/Debian host is created in the Bare Metal portal, the HPE On-Premises Controller will pull down this Bare Metal modified Ubuntu/Debian .ISO file.

### hpe-build-image-and-service.sh - the top-level build script

This is the top-level build script that will take a Ubuntu/Debian install ISO and generate a Ubuntu/Debian service .yml file that can be imported as a Host OS into a Bare Metal portal.

This script 'hpe-build-image-and-service.sh' does the following steps:
* process command line arguments.
* Customize the Ubuntu/Debian .ISO so that it works for Bare Metal.  Run: `hpe-image-build.sh`
* Generate the Bare Metal service file for this Bare Metal image that we just generated. Run: `hpe-service-build.sh`

Usage:

```
./hpe-build-image-and-service.sh \
    -i <distro-iso-filename> \
    -v <distro-version-number> \
    -n <distro-version-name> \
    -r <distro-rootpw> \
    -p <image-url-prefix> \
    -o <distro-tar-file> \
    -s <distro-service-file> \
    -x <skip-test>
```

Command Line Options            | Description
------------------------------- | -----------
-i \<distro-iso-filename\>      | local filename of the standard Ubuntu/Debian .ISO file that was already downloaded. Used as input file.
-v \<distro-version-number\>    | a x.y Ubuntu/Debian version number.  Example: -v 12.5.0
-n \<distro-version-name\>      | distro name: Ubuntu or Debian
-r \<distro-rootpw\>            | user defined Ubuntu/Debian Linux OS root password
-p \<image-url-prefix\>         | the beginning of the image URL (on your web server). Example: -p https://<web-server-address>.
-o \<distro-tar-file\>          | local filename of the Bare Metal modified Ubuntu/Debian .tar file that will be output by the script.  This file should be uploaded to your web server.
-s \<distro-service-file\>      | local filename of the Bare Metal .YML service file that will be output by the script.  This file should be uploaded to the Bare Metal portal.
-x \<skip-test>                 | [optional] skip the test with "-x true". <br> **_NOTE:_**  <br> By default, this script will run the test [hpe-test-service-image.sh](hpe-test-service-image.sh) script to verify that the upload was correct, and the size and checksum of the ISO match what is defined in the YML.

> **_NOTE:_**  The users of this script are expected to copy the \<distro-baremetal-iso\> .ISO file to your web server
> such that the file is available at this constructed URL: \<image-url-prefix\>/\<distro-baremetal-iso\>.
> The Bare Metal service .YML will assume that the image file will be available at a URL constructed with \<image-url-prefix\>/\<distro-baremetal-iso\>.

### hpe-image-build.sh - Customize distro.ISO for Bare Metal

This script will pack a GLM-modified Ubuntu/Debian .ISO file and cloud-init packages into a GLM Ubuntu/Debian .tar file. The GLM-modified Ubuntu/Debian .ISO file is generated by calling hpe-iso-build.sh and passing in the regular Ubuntu/Debian .ISO. The cloud-init packages are not present in the Ubuntu/Debian .ISO so we will pull the cloud-init package and dependencies from the network using aptly.

The script hpe-iso-build.sh will repack Ubuntu/Debian .ISO file for a GLM Ubuntu/Debian install service that uses Virtual Media to get the install started.

The following changes are being made to the Ubuntu/Debian .ISO:
  1. configure to use a DebianInstaller Preseed file on the iLO vmedia-floppy
  3. setup for a text-based install (versus a GUI install)
  4. set up the console to the iLO serial port (/dev/ttyS1)
  5. eliminate the 'media check' when installing so that we get faster deployments (and parity with TGZ installs)

The Ubuntu/Debian .ISO is configured to use a DebianInstaller Preseed Setup Configuration file on the iLO vmedia-cd by adding the
'auto=true preseed\/file=\/cdrom\/hpe-preseed_setup.cfg' option in GRUB (used in UEFI) and isolinux (used in BIOS) configuration files. This option configures the Ubuntu/Debian installer to pull the DebianInstaller Preseed file from the root of the cdrom at /preseed.cfg.
This preseed option is setup by modifying the following files on the .ISO:
  isolinux/isolinux.cfg for BIOS
  boot/grub/grub.cfg for UEFI

Usage:
```
hpe-image-build.sh \
    -i <distro.iso> \
    -o <distro.tar>
```

Command Line Options    | Description
----------------------- | -----------
-i \<distro.iso\>       | Input Ubuntu/Debian .ISO filename
-o \<distro.tar\>       | Output Bare Metal Ubuntu/Debian .ISO file

Example:

```
sudo ./hpe-image-build.sh \
    -i debian-12.5.0-amd64-DVD-1.iso \
    -o debian.tar
```

Here are the detailed changes that are made to the Ubuntu/Debian .ISO:
* change the default timeout to 0 seconds
* change the default menu selection to the 1st entry (no media check)
* add the 'auto=true preseed\/file=\/cdrom\/hpe-preseed_setup.cfg' option to the various lines in the file
* also setup the serial console to ttyS1 (iLO serial port) with 115200 baud
* remove the 'quiet' option so the user can watch kernel loading and use to triage any problems

### hpe-service-build.sh - Generate Bare Metal .YML service file

This script `hpe-service-build.sh` generates a Bare Metal OS service .yml file appropriate for uploading to a Bare Metal portal(s).

Usage:
```
hpe-service-build.sh \
    -s <service-template> \
    -o <service_yml_filename> \
    -c <svc_category> \
    -f <scv_flavor> \
    -v <svc_ver> \
    -d <display_url> \
    -u <secure_url> \
    -i <local_image_filename> [ -t <os-template> ]
```

Command Line Options        | Description
--------------------------- | -----------
-s \<service-template\>     | service template filename (input file)
-o \<service_yml_filename\> | service filename (output file)
-c \<svc_category\>         | the Bare Metal service category
-f \<scv_flavor\>           | the Bare Metal service flavor
-v \<svc_ver\>              | the Bare Metal service version
-d \<display_url\>          | used to display the image URL in the user interface
-u \<secure_url\>           | the real URL to the image file
-i \<local_image_filename\> | a full path to the image for this service. Used to get the .ISO sha256sum and size.
[ -t \<os-template\> ]      | info template files. 1st -t option should be %CONTENT1% in service-template. 2nd -> %CONTENT2%.

Example:
```
./hpe-service-build.sh \
    -s /tmp/hpe-service.cfg.5k70efrzd \
    -o distro.yml \
    -c linux \
    -f debian \
    -v 12.5.0-20240620-BYOI \
    -u https://<web-server-address>/distro.tar \
    -d distro-12.5.0-amd64-DVD-1.iso \
    -i distro.tar \
    -t hpe-preseed.cfg.template \
    -t hpe-cloud-init.template \
    -t hpe-apt-cloud-init.list.template"
```

### hpe-test-service-image.sh - Verify the Bare Metal OS image

This script `hpe-test-service-image.sh` will verify that the OS image referred to in a corresponding Bare Metal OS service. yml is correct.

Usage:
```
/hpe-test-service-image.sh debian-12.5.0-amd64-GLM.yml
```

Command Line Options     | Description
------------------------ | -----------
\<distro-service-file\>  | service filename (output file)

Example:
```
./hpe-test-service-image.sh debian-12.5.0-amd64-GLM.yml
```

# Customizing Ubuntu or Debian image

The Ubuntu/Debian image/service can be customized by:
* Modifying the way the image is built
* Modifying the DebianInstaller Preseed file

## Modifying the way the image is built

Here is a description of the files in this repo:

Filename                         | Description
-------------------------------- | -----------
README.md                        | This documentation
hpe-build-image-and-service.sh   | This is the top-level build script that will take an Ubuntu/Debian install ISO and generate an Ubuntu/Debian service .yml file that can be imported as a Host OS into a Bare Metal portal.
hpe-image-build.sh               | This script will pack a GLM-modified Ubuntu/Debian .ISO file and cloud-init packages into a GLM Ubuntu/Debian .tar file. The GLM-modified Ubuntu/Debian .ISO file is generated by calling hpe-iso-build.sh and passing in the regular Ubuntu/Debian .ISO. The cloud-init packages are not present in the Ubuntu/Debian .ISO so we will pull the cloud-init package and dependencies from the network using aptly.
hpe-iso-build.sh                 | This script will repack Ubuntu/Debian .ISO file for a GLM Ubuntu/Debian install service that uses Virtual Media to get the install started.
hpe-service-build.sh             | This script generates a Bare Metal OS service .yml file appropriate for uploading the service to a Bare Metal portal(s).
hpe-test-service-image.sh        | This script will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct.
hpe-service.yml.template         | This is the Bare Metal .YML service file template.
hpe-preseed_setup.cfg            | Initial preseed setup configuration file which triggers the final DebianInstaller Preseed file.
hpe-preseed.cfg.template         | The core DebianInstaller Preseed file (templated with hostdef-v3)
hpe-apt-cloud-init.list.template | The configuration file for Linux's apt tool, that holds URLs and other information for remote repositories from where software packages are installed (templated with install-env-v1)
Hosting.md                       | This file is for additional requirements on the web server.

Feel free to modify these files to suit your specific needs.
General changes that you want to contribute back via a pull request are much appreciated.

## Modifying the DebianInstaller Preseed file

The DebianInstaller Preseed file is the basis of the automated install of Ubuntu/Debian supplied by this recipe.
Many additional changes to either of the Preseed files are possible to customize to your needs.

# Using the Ubuntu or Debian service and image

## Adding Ubuntu or Debian service to Bare Metal portal

When the build script completes successfully, you will find the following instructions to add this image to your HPE Bare Metal portal.

For example (the build results including artifact verification):
```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal debian service/image
| | that consists of the following 2 new files:
| |     images/debian-12.5.0-amd64-GLM.iso
| |     images/debian-12.5.0-amd64-GLM.yml
| |
| | To use this new Bare Metal debian service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (images/debian-12.5.0-amd64-GLM.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/debian-12.5.0-amd64-GLM.iso
| |
| | (2) Add the Bare Metal Service file (images/debian-12.5.0-amd64-GLM.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

For example (the build results excluding artifact verification):
```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal debian service/image
| | that consists of the following 2 new files:
| |     images/debian-12.5.0-amd64-GLM.iso
| |     images/debian-12.5.0-amd64-GLM.yml
| |
| | To use this new Bare Metal debian service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (images/debian-12.5.0-amd64-GLM.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/debian-12.5.0-amd64-GLM.iso
| |
| |     IMPORTANT: Use the test (hpe-test-service-image.sh) script to verify that
| |                the ISO upload was correct, and the size and checksum of the ISO
| |                match what is defined in the YML.
| |
| | (2) Add the Bare Metal Service file (images/debian-12.5.0-amd64-GLM.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

Follow the instructions as directed!

## Creating a Ubuntu or Debian Host with Ubuntu or Debian Service

Create a host in Bare Metal using this OS image service.

## Triage of image deployment problems

After you have created your custom Ubuntu/Debian image/server and created a host using this new service, you will want to monitor the deployment so for the first few times, make sure things are going as expected.
Here are some points to note:
  * This image/service is set to output to the serial console during Ubuntu/Debian deployment and watching the serial console is the easiest way to monitor the Ubuntu/Debian deployment/installation.
  * HPE GreenLake Metal tools do not monitor the serial port(s) at this time so if an error is generated by the Ubuntu/Debian installer, the Bare Metal tools will not know about it.
  * Sometimes for more difficult OS deployment problems you might want to gain access to the servers iLO so that you can monitor it that way. See your Bare Metal administrator.

## Known Observations and Limitations

<1> Host readiness for the user to log in  
After the host is created successfully, the Portal UI shows progress 100%.  
However, the host OS is still booting up in the background, resulting in user login (serial console login and SSH login) being delayed by 5 to 10 minutes.

## Ubuntu or Debian License

Ubuntu/Debian is a licensed software and users need to have a valid license key from Ubuntu/Debian to use Ubuntu/Debian.
This install service does nothing to set up a Ubuntu/Debian license key in any way.
Users are expected to manually use Ubuntu/Debian tools to set up a Ubuntu/Debian license on the host.

## Storage Volumes iSCSI and FC

When a Bare Metal host is set up with iSCSI or FC volumes, the storage volume should be automatically available.
