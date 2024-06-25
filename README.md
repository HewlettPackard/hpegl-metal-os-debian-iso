<!-- (C) Copyright 2024 Hewlett Packard Enterprise Development LP -->

Debian Bring Your Own Image (BYOI) for HPE Private Cloud Enterprise - Bare Metal
=============================

* [Overview](#overview)
* [Example of manual build for reference](#example-of-manual-build-for-reference)
* [Building Debian image](#building-Debian-image)
  *   [Setup Linux system for imaging build](#setup-linux-system-for-imaging-build)
  *   [Downloading recipe repo from GitHub](#downloading-recipe-repo-from-github)
  *   [Downloading Debian ISO file](#downloading-Debian-iso-file)
  *   [Building the Bare Metal Debian image and service](#building-the-bare-metal-Debian-image-and-service)
* [Customizing Debian image](#customizing-Debian-image)
  *   [Modifying the way the image is built](#modifying-the-way-the-image-is-built)
* [Using the Debian service and image](#using-the-Debian-service-and-image)
  *   [Adding Debian service to Bare Metal portal](#adding-Debian-service-to-bare-metal-portal)
  *   [Creating a Debian Host with Debian Service](#creating-a-Debian-host-with-Debian-service)
  *   [Triage of image deployment problems](#triage-of-image-deployment-problems)
  *   [Debian License](#Debian-license)
  *   [Known Observations/Issues](#known-observations-and-issues)
  *   [Debian License](#Debian-license)
  *   [Storage Volumes iSCSI and FC](#storage-volumes-iscsi-and-fc)


----------------------------------

# Overview

This GitHub repository contains the script files, template files, and documentation for creating an Debian service for HPE Bare Metal from an Debian install .ISO file.  By building a custom image via this process, you can control the exact version of Debian that is used and modify how Debian is installed via a DebianInstaller Preseed file.  Once the build is done, you can add your new service to the HPE Bare Metal Portal and deploy a host with that new image.

# Example of manual build for reference

Workflow for Building Image:

![image](https://github.com/hpe-hcss/bmaas-byoi-debian-build/assets/90067804/e7145718-9099-4f8e-a776-a1f5f89c28c9)


Prerequisites:
```
1. You will need a Web Server with HTTPS support for storage of the HPE Base Metal images.  The Web Server is anything that:
   A. You have the ability to upload large .ISO image to and
   B. The Web Server must be on a network that will be reachable from the HPE On-Premises Controller.  When an OS service/image is used to create an HPE Bare Metal Host the OS images will be downloaded via the secure URL in the service file.
   NOTE: For this manual build example, a local Web Server "https://<web-server-address>" is used for OS image storage.  For this example, we are assuming that the HPE Bare Metal OS bundle will be kept in: https://<web-server-address><.tar>.
2. Linux machine for building OS image
   A. Ubuntu 20.04.6 LTS
   B. Install supporting tools (git, xorriso, isomd5sum, isolinux, and aptly)
```

Step 1. Source code readiness

A. Clone the GitHub Repo `hpegl-metal-os-debian-iso`
```
git clone https://github.com/HewlettPackard/hpegl-metal-os-debian-iso.git
```
B. Change the directory to `hpegl-metal-os-debian-iso`

Step 2. Download the Debian .ISO image to your local build environment via what ever method you prefer (Web Browser, etc)

For example, we will assume that you have downloaded debian-12.5.0-amd64-DVD-1.iso into the local directory.

Step 3. Run the script `hpe-build-image-and-service.sh` to generate an output Bare Metal image bundle .tar as well as Bare Metal Service .yml:

Example:
```
./hpe-build-image-and-service.sh \
  -v 12.5.0 \
  -p https://<web-server-address> \
  -r qPassw0rd \
  -i debian-12.5.0-amd64-DVD-1.iso \
  -o debian.tar \
  -s debian.yml
```

Example test result for reference:
```
TBD
```

Step 4. Copy the output Bare Metal image bundle .tar to the Web Server.

Step 5. Run the script `hpe-test-service-image.sh`, which will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct:
> **_NOTE:_** This script will verify that it can download the OS image and check its length (in bytes) and signature.
> The script simulates what HPE On-Premises Controller will do when it tries to download and verify an OS image.
> If this script fails then the Bare Metal OS service .yml file is most likely broken and will not work if loaded into Bare Metal.

Example:
```
./hpe-test-service-image.sh debian.yml
```

Test result for reference:

```
TBD
```

Step 6. Add the Bare Metal service .yml file to the appropriate Bare Metal portal.

To add the Bare Metal service .yml file, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
Select the Dashboard tile "Metal Consumption" and click on the tab "OS/application images".
Click on the button "Add OS/application image" to upload this service .yml file.

Step 7. Create a new Bare Metal host using this OS image service.

To create a new Bare Metal host, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
Select the Dashboard tile "Metal Consumption" and click on the tab "Compute groups". Further, create a host using the following steps:
a. First create a Compute Group by clicking the button "Create compute group" and fill in the details.
b. Create a Compute Instance by clicking the button "Create compute instance" and fill in the details.


# Building Debian image

These are the high-level steps required to generate the Bare Metal Debian service:
* Set up a Linux system with 20-40GB of free file system space for the build
* Set up a local file transfer/storage tool (E.g. Local Web Server with HTTPS support) that Bare Metal can reach over the network.
* Install Git Version Control (git) and other supporting tools (xorriso, isomd5sum, isolinux, and aptly)
* Downloading recipe repo from GitHub
* Download a Debian .ISO file
* Build the Bare Metal Debian image/service

These are the high-level steps required to use this built Bare Metal Debian service/image on Bare Metal:
* Copy the built Bare Metal Debian .ISO image to your web server
* Add the Bare Metal Debian .YML service file to the appropriate Bare Metal portal
* In Bare Metal, create a host using this Debian image service

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
aptly         | a debian repository management tool.

On Ubuntu 20.04 VM, the necessary packages can be installed with:

```
sudo apt install -y git xorriso isomd5sum isolinux aptly
```

> **_NOTE:_**  You must also have sudo (superuser do) capability so that you can mount the Debian ISO
> and copy the files from it to generate a new Debian .ISO file for Bare Metal.

The resulting Debian .ISO image file from the build, needs to be uploaded to a web server that
the HPE On-Premises Controller can access over the network.  More about this later.

## Downloading recipe repo from GitHub

Once you have an appropriate Linux environment setup, then download this recipe from GitHub
for building the HPE Bare Metal Debian by:

```
git clone https://github.com/HewlettPackard/hpegl-metal-os-debian-iso.git
```

## Downloading Debian .ISO file

Next, you will need to manually download the appropriate Debian .ISO onto the Linux system.
This Debian recipe has been successfully tested with the following list of Debian distributions and its derivatives:
* Debian 12.5

> **_NOTE:_**  This recipe should work on other Debian or Debian-based distros that support the same DebianInstaller Preseed and .ISO construction as recent version of Debian.

## Building the Bare Metal Debian image and service

At this point, you should have a Linux system with:
* a copy of this repo
* a standard Debian .ISO file

We are almost ready to do the build, but we need to know something about your environment.
When the build is done, it will generate two files:
* a Bare Metal modified Debian .ISO file that needs to be hosted on a web server.
  It is assumed that you have (or can set up) a local web server that Bare Metal can reach over the network.
  You will also need login credentials on this Web Server so that you can upload the files.
* a Bare Metal service .YML file that will be used to add the Debian service to the portal.
  This .YML file will have a URL to the Bare Metal modified Debian .ISO file on the web server.

The build needs to know what URL can be used to download the Bare Metal modified Debian .ISO file.
We assume that the URL can be broken into 2 parts: \<image-url-prefix\>/\<bare-metal-custom-bebian-iso\>

If the image URL can not be constructed with this simple mechanism, then you probably need to
customize this script for a more complex URL construction.

So you can run the build with the following command line parameters:

```
./hpe-build-image-and-service.sh \
    -i <debian-iso-filename> \
    -v <debian-version-number> \
    -r <debian-rootpw> \
    -p <image-url-prefix> \
    -o <debian-tar-file> \
    -s <debian-service-file>
```

When a Debian host is created in the Bare Metal portal, the HPE On-Premises Controller will pull down this Bare Metal modified Debian .ISO file.

### hpe-build-image-and-service.sh - the top-level build script

This is the top-level build script that will take a Debian install ISO and generate a Debian service .yml file that can be imported as a Host OS into a Bare Metal portal.

This script 'hpe-build-image-and-service.sh' does the following steps:
* process command line arguments.
* Customize the Debian .ISO so that it works for Bare Metal.  Run: `hpe-image-build.sh`
* Generate the Bare Metal service file for this Bare Metal image that we just generated. Run: `hpe-service-build.sh`

Usage:

```
./hpe-build-image-and-service.sh \
    -i <debian-iso-filename> \
    -v <debian-version-number> \
    -r <debian-rootpw> \
    -p <image-url-prefix> \
    -o <debian-tar-file> \
    -s <debian-service-file>
```

Command Line Options            | Description
------------------------------- | -----------
-i \<debian-iso-filename\>      | local filename of the standard Debian .ISO file that was already downloaded. Used as input file.
-v \<debian-version-number\>    | a x.y Debian version number.  Example: -v 12.5.0
-r \<debian-rootpw\>            | user defined Debian Linux OS root password
-p \<image-url-prefix\>         | the beginning of the image URL (on your web server). Example: -p https://<web-server-address>.
-o \<debian-tar-file\>          | local filename of the Bare Metal modified Debian .tar file that will be output by the script.  This file should be uploaded to your web server.
-s \<debian-service-file\>      | local filename of the Bare Metal .YML service file that will be output by the script.  This file should be uploaded to the Bare Metal portal.

> **_NOTE:_**  The users of this script are expected to copy the \<debian-baremetal-iso\> .ISO file to your web server
> such that the file is available at this constructed URL: \<image-url-prefix\>/\<debian-baremetal-iso\>.
> The Bare Metal service .YML will assume that the image file will be available at a URL constructed with \<image-url-prefix\>/\<debian-baremetal-iso\>.

### hpe-image-build.sh - Customize debian.ISO for Bare Metal

This script will pack a GLM-modified Debian .ISO file and cloud-init packages into a GLM Debian .tar file. The GLM-modified Debian .ISO file is generated by calling hpe-iso-build.sh and passing in the regular Debian .ISO. The cloud-init packages are not present in the Debian .ISO so we will pull the cloud-init package and dependencies from the network using aptly.

The script hpe-iso-build.sh will repack Debian .ISO file for a GLM Debian install service that uses Virtual Media to get the install started.

The following changes are being made to the Debian .ISO:
  1. configure to use a DebianInstaller Preseed file on the iLO vmedia-floppy
  3. setup for a text-based install (versus a GUI install)
  4. set up the console to the iLO serial port (/dev/ttyS1)
  5. eliminate the 'media check' when installing so that we get faster deployments (and parity with TGZ installs)

The Debian .ISO is configured to use a DebianInstaller Preseed Setup Configuration file on the iLO vmedia-cd by adding the
'auto=true preseed\/file=\/cdrom\/hpe-preseed_setup.cfg' option in GRUB (used in UEFI) and isolinux (used in BIOS) configuration files. This option configures the Debian installer to pull the DebianInstaller Preseed file from the root of the cdrom at /preseed.cfg.
This preseed option is setup by modifying the following files on the .ISO:
  isolinux/isolinux.cfg for BIOS
  boot/grub/grub.cfg for UEFI

Usage:
```
hpe-image-build.sh \
    -i <debian.iso> \
    -o <debian.tar>
```

Command Line Options    | Description
----------------------- | -----------
-i \<debian.iso\>       | Input Debian .ISO filename
-o \<debian.tar\>       | Output Bare Metal Debian .ISO file

Example:

```
sudo ./hpe-image-build.sh \
    -i debian-12.5.0-amd64-DVD-1.iso \
    -o debian.tar
```

Here are the detailed changes that are made to the Debian .ISO:
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
    -o debian.yml \
    -c linux \
    -f debian \
    -v 12.5.0-20240620-BYOI \
    -u https://<web-server-address>/debian.tar \
    -d debian-12.5.0-amd64-DVD-1.iso \
    -i debian.tar \
    -t hpe-preseed.cfg.template \
    -t hpe-cloud-init.template \
    -t hpe-apt-cloud-init.list.template"
```

### hpe-test-service-image.sh - Verify the Bare Metal OS image

This script `hpe-test-service-image.sh` will verify that the OS image referred to in a corresponding Bare Metal OS service. yml is correct.

Usage:
```
$ ./hpe-test-service-image.sh debian-12.5.0-amd64-DVD-1-service-20240625-19146.yml
OS image file to be tested:
  Secure URL: https://d1xrzz3jml13a5.cloudfront.net/images/linux/Debian/12.5.0-20240625-BYOI/debian-12.5.0-amd64-DVD-1-hpe-glm-20240625-19146.tar?Expires=2034633600&Signature=SjzkC0hYqJEnHyga1RNdzGaP5dRF1D2UIVosHINzoUV4KmuVsGpIXJOY4FuyapRfE7Xc1xyKU4YpN2TEVZDHlQfHgr6y2Sy1RLtO0r0MLLQWuXumeakqtBPhAimKD0ES57gt-7pQ4jQtTPOwPeLjpplW9RZYFwt9Ze3RkjTqBIAdUMA5E8uwTg5Xw9rYf2AImpe6cVIKHRCi-~pciTwAWmEiuFOO1gNlqq~fkEeFMlQRErxNklrVOGLIOprJ~P2t~4kzAtvYU9ysAsiKGZlRYwvQ-D0CKDSp51nvgAdDxsdpP95RtBLgctgHlthfMBLc~02OemsH46Yowus-SpJ9Hg__&Key-Pair-Id=K27J47UY2Q7IFN
  Display URL: s3://quake-images20210506193558893900000003/images/linux/Debian/12.5.0-20240625-BYOI/debian-12.5.0-amd64-DVD-1-hpe-glm-20240625-19146.tar
  Image size: 4165642240
  Image signature: 4605e88a02822b6ce0c8184ae1851a65a3979b4f7e3c05f65c4e5fc7917e4468
  Signature algorithm: sha256sum

wget -O /tmp/os-image-OpAzS7.img https://d1xrzz3jml13a5.cloudfront.net/images/linux/Debian/12.5.0-20240625-BYOI/debian-12.5.0-amd64-DVD-1-hpe-glm-20240625-19146.tar?Expires=2034633600&Signature=SjzkC0hYqJEnHyga1RNdzGaP5dRF1D2UIVosHINzoUV4KmuVsGpIXJOY4FuyapRfE7Xc1xyKU4YpN2TEVZDHlQfHgr6y2Sy1RLtO0r0MLLQWuXumeakqtBPhAimKD0ES57gt-7pQ4jQtTPOwPeLjpplW9RZYFwt9Ze3RkjTqBIAdUMA5E8uwTg5Xw9rYf2AImpe6cVIKHRCi-~pciTwAWmEiuFOO1gNlqq~fkEeFMlQRErxNklrVOGLIOprJ~P2t~4kzAtvYU9ysAsiKGZlRYwvQ-D0CKDSp51nvgAdDxsdpP95RtBLgctgHlthfMBLc~02OemsH46Yowus-SpJ9Hg__&Key-Pair-Id=K27J47UY2Q7IFN
--2024-06-25 14:51:33--  https://d1xrzz3jml13a5.cloudfront.net/images/linux/Debian/12.5.0-20240625-BYOI/debian-12.5.0-amd64-DVD-1-hpe-glm-20240625-19146.tar?Expires=2034633600&Signature=SjzkC0hYqJEnHyga1RNdzGaP5dRF1D2UIVosHINzoUV4KmuVsGpIXJOY4FuyapRfE7Xc1xyKU4YpN2TEVZDHlQfHgr6y2Sy1RLtO0r0MLLQWuXumeakqtBPhAimKD0ES57gt-7pQ4jQtTPOwPeLjpplW9RZYFwt9Ze3RkjTqBIAdUMA5E8uwTg5Xw9rYf2AImpe6cVIKHRCi-~pciTwAWmEiuFOO1gNlqq~fkEeFMlQRErxNklrVOGLIOprJ~P2t~4kzAtvYU9ysAsiKGZlRYwvQ-D0CKDSp51nvgAdDxsdpP95RtBLgctgHlthfMBLc~02OemsH46Yowus-SpJ9Hg__&Key-Pair-Id=K27J47UY2Q7IFN
Resolving web-proxy.corp.hpecorp.net (web-proxy.corp.hpecorp.net)... 10.78.90.46
Connecting to web-proxy.corp.hpecorp.net (web-proxy.corp.hpecorp.net)|10.78.90.46|:8080... connected.
Proxy request sent, awaiting response... 200 OK
Length: 4165642240 (3.9G) [application/x-tar]
Saving to: ‘/tmp/os-image-OpAzS7.img’

/tmp/os-image-OpAzS7.img                 100%[===============================================================================>]   3.88G  5.15MB/s    in 8m 15s

2024-06-25 14:59:49 (8.02 MB/s) - ‘/tmp/os-image-OpAzS7.img’ saved [4165642240/4165642240]

Image Size has been verified ( 4165642240 bytes )
Image Signature has been verified ( 4605e88a02822b6ce0c8184ae1851a65a3979b4f7e3c05f65c4e5fc7917e4468 )
The OS image size and signature have been verified
$
```

Command Line Options     | Description
------------------------ | -----------
\<debian-service-file\>  | service filename (output file)

Example:
```
./hpe-test-service-image.sh debian.yml
```

# Customizing Debian image

The Debian image/service can be customized by:
* Modifying the way the image is built
* Modifying the DebianInstaller Preseed file

## Modifying the way the image is built

Here is a description of the files in this repo:

Filename                         | Description
-------------------------------- | -----------
README.md                        | This documentation
hpe-build-image-and-service.sh   | This is the top-level build script that will take an Debian install ISO and generate an Debian service .yml file that can be imported as a Host OS into a Bare Metal portal.
hpe-image-build.sh               | This script will pack a GLM-modified Debian .ISO file and cloud-init packages into a GLM Debian .tar file. The GLM-modified Debian .ISO file is generated by calling hpe-iso-build.sh and passing in the regular Debian .ISO. The cloud-init packages are not present in the Debian .ISO so we will pull the cloud-init package and dependencies from the network using aptly.
hpe-iso-build.sh                 | This script will repack Debian .ISO file for a GLM Debian install service that uses Virtual Media to get the install started.
hpe-service-build.sh             | This script generates a Bare Metal OS service .yml file appropriate for uploading the service to a Bare Metal portal(s).
hpe-test-service-image.sh        | This script will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct.
hpe-service.yml.template         | This is the Bare Metal .YML service file template.
hpe-preseed_setup.cfg            | Initial preseed setup configuration file which triggers the final DebianInstaller Preseed file.
hpe-preseed.cfg.template         | The core DebianInstaller Preseed file (templated with hostdef-v3)
hpe-apt-cloud-init.list.template | The configuration file for Linux's apt tool, that holds URLs and other information for remote repositories from where software packages are installed (templated with install-env-v1)

Feel free to modify these files to suit your specific needs.
General changes that you want to contribute back via a pull request are much appreciated.

## Modifying the DebianInstaller Preseed file

The DebianInstaller Preseed file is the basis of the automated install of Debian supplied by this recipe.
Many additional changes to either of the Preseed files are possible to customize to your needs.

# Using the Debian service and image

## Adding Debian service to Bare Metal portal

When the build script completes successfully, you will find the following instructions to add this image to your HPE Bare Metal portal.
For example:

```
TBD
```

Follow the instructions as directed!

## Creating a Debian Host with Debian Service

Create a host in Bare Metal using this OS image service.

## Triage of image deployment problems

After you have created your custom Debian image/server and created a host using this new service, you will want to monitor the deployment so for the first few times, make sure things are going as expected.
Here are some points to note:
  * This image/service is set to output to the serial console during Debian deployment and watching the serial console is the easiest way to monitor the Debian deployment/installation.
  * HPE GreenLake Metal tools do not monitor the serial port(s) at this time so if an error is generated by the Debian installer, the Bare Metal tools will not know about it.
  * Sometimes for more difficult OS deployment problems you might want to gain access to the servers iLO so that you can monitor it that way. See your Bare Metal administrator.

## Known Observations/Issues

None

## Debian License

Debian is a licensed software and users need to have a valid license key from Debian to use Debian.
This install service does nothing to set up a Debian license key in any way.
Users are expected to manually use Debian tools to set up a Debian license on the host.

## Storage Volumes iSCSI and FC

When a Bare Metal host is set up with iSCSI or FC volumes, the storage volume should be automatically available.
