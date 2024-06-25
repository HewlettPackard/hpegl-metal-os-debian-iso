#!/bin/bash
# (C) Copyright 2018-2022, 2024 Hewlett Packard Enterprise Development LP

# This is the top-level build script that will take an Debian install ISO and
# generate a Debian service.yml file that can be imported as a Host OS into
# a Bare Metal portal.

# hpe-build-image-and-service.sh does the following steps:
# * process command line arguements.
# * Customize the Debian .ISO so that it works for Bare Metal.  Run: hpe-image-build.sh.
# * Generate Bare Metal service file that is specific to $OS_VER. Run: hpe-service-build.sh.

# hpe-build-image-and-service.sh usage:
# hpe-build-image-and-service.sh -i <debian-iso-filename> -o <hpe-customer-debian-tar>
#    -v <debian-version-number> -p <image-url-prefix> -s <hpe-yml-service-file>

# command line options         | Description
# ---------------------------- | -----------
# -i <debian-iso-filename>     | local filename of the standard Debian .ISO file
#                              | that was already downloaded. Used as input file.
# ---------------------------- | -----------
# -v <debian-version-number>   | a x.y Debian version number.  Example: -v 12.5
# ---------------------------- | -----------
# -r <rootpw>                  | set the Debian OS root password
# ---------------------------- | -----------
# -o <hpe-customer-debian-tar> | local filename of the Bare Metal modified Debian .tar file
#                              | that will be output by the script.  This file should
#                              | be uploaded to your web server.
# ---------------------------- | -----------
# -p <image-url-prefix>        | the beginning of the image URL (on your web server).
#                              | Example: -p http://192.168.1.131.  The Bare Metal service .YML
#                              | will assume that the image file will be available at
#                              | a URL constructed with <image-url-prefix>/<hpe-customer-debian-tar>.
# ---------------------------- | -----------
# -s <hpe-yml-service-file>    | local filename of the Bare Metal .YML service file that
#                              | will be output by the script.  This file should
#                              | be uploaded to the Bare Metal portal.
# ---------------------------- | -----------

# NOTE: The user's of this script are expected to copy the
# <hpe-customer-debian-tar> .ISO file to your web server such
# that the file is available at this constructed URL:
# <image-url-prefix>/<hpe-customer-debian-tar>

# If the image URL can't not be constructed with this
# simple mechanism then you probably need to customize
# this script for a more complex URL costruction.

# This script calls hpe-image-build.sh, which interm
# calls hpe-iso-build.sh, which needs the following
# packages to be installed:
#
# on Debian/Ubuntu:
#  sudo apt install xorriso isomd5sum

set -euo pipefail

# required parameters
DEBIAN_ISO_FILENAME=""
GLM_CUSTOM_DEBIAN_TAR=""
OS_VER=""
DEBIAN_ROOTPW=""
IMAGE_URL_PREFIX=""
GLM_YML_SERVICE_FILE=""
GLM_YML_SERVICE_TEMPLATE=""

while getopts "i:v:r:o:p:s:" opt
do
    case $opt in
        # required parameters
        i) DEBIAN_ISO_FILENAME=$OPTARG ;;
        v) OS_VER=$OPTARG ;;
        r) DEBIAN_ROOTPW=$OPTARG ;;
        o) GLM_CUSTOM_DEBIAN_TAR=$OPTARG ;;
        p) IMAGE_URL_PREFIX=$OPTARG ;;
        s) GLM_YML_SERVICE_FILE=$OPTARG ;;
     esac
done

# Check that required parameters exist.
if [ -z "$DEBIAN_ISO_FILENAME" -o \
     -z "$GLM_CUSTOM_DEBIAN_TAR" -o \
     -z "$OS_VER" -o \
     -z "$DEBIAN_ROOTPW" -o \
     -z "$IMAGE_URL_PREFIX" -o \
     -z "$GLM_YML_SERVICE_FILE" ]; then
  echo "script usage: $0 -i debian-iso -v debian-version -r debian-rootpw" >&2
  echo "              -o hpe-customer-debian-tar -p http-prefix -s hpe-yml-service-file" >&2
  exit 1
fi

if [[ ! -f $DEBIAN_ISO_FILENAME ]]; then
  echo "ERROR missing ISO image file $DEBIAN_ISO_FILENAME"
  exit 1
fi

# The clean function cleans up any lingering files
# that might be present when the script exits.
clean() {
  if [ ! -z "$GLM_YML_SERVICE_TEMPLATE" ]; then
    rm -f $GLM_YML_SERVICE_TEMPLATE
  fi
}

trap clean EXIT

# if the Bare Metal customized DEBIAN .ISO has not already been generated.
if [ ! -f $GLM_CUSTOM_DEBIAN_TAR ]; then
   # Customize the DEBIAN .ISO so that it works for Bare Metal.
   GEN_IMAGE="sudo ./hpe-image-build.sh \
      -i $DEBIAN_ISO_FILENAME \
      -o $GLM_CUSTOM_DEBIAN_TAR"
   echo $GEN_IMAGE
   $GEN_IMAGE
fi

GLM_YML_SERVICE_TEMPLATE=$(mktemp /tmp/hpe-service.cfg.XXXXXXXXX)
sed -e "s/%OS_VERSION%/$OS_VER/g" hpe-service.yml.template > $GLM_YML_SERVICE_TEMPLATE

# set the root password in the KS configuration file (here, hpe-preseed.cfg.template)
sed -i "s/%ROOTPW%/$DEBIAN_ROOTPW/g" hpe-preseed.cfg.template

# extract the Service Flavor from the GLM_CUSTOM_DEBIAN_TAR
SVC_FLAVOR=Debian

# Generate HPE Bare Metal service file.
YYYYMMDD=$(date '+%Y%m%d')
GEN_SERVICE="./hpe-service-build.sh \
  -s $GLM_YML_SERVICE_TEMPLATE \
  -o $GLM_YML_SERVICE_FILE \
  -c linux \
  -f $SVC_FLAVOR \
  -v $OS_VER-$YYYYMMDD-BYOI \
  -u $IMAGE_URL_PREFIX/$GLM_CUSTOM_DEBIAN_TAR \
  -d $DEBIAN_ISO_FILENAME \
  -i $GLM_CUSTOM_DEBIAN_TAR \
  -t hpe-preseed.cfg.template \
  -t hpe-cloud-init.template \
  -t hpe-apt-cloud-init.list.template"
echo $GEN_SERVICE
$GEN_SERVICE

# unset the root password in the KS configuration file (here, hpe-preseed.cfg.template)
sed -i '/d-i passwd/root-password password/c\d-i passwd\/root-password password %ROOTPW%' hpe-preseed.cfg.template
sed -i '/d-i passwd\/root-password password-again password/c\d-i passwd\/root-password password-again password %ROOTPW%' hpe-preseed.cfg.template

# print out instructions for using this image & service
cat << EOF
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal $SVC_FLAVOR service/image
| | that consists of the following 2 new files:
| |     $GLM_CUSTOM_DEBIAN_TAR
| |     $GLM_YML_SERVICE_FILE
| |
| | To use this new Bare Metal $SVC_FLAVOR service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file ($GLM_CUSTOM_DEBIAN_TAR)
| |     to your web server ($IMAGE_URL_PREFIX)
| |     such that the file can be downloaded from the following URL:
| |     $IMAGE_URL_PREFIX/$GLM_CUSTOM_DEBIAN_TAR
| | (2) Use the script "hpe-test-service-image.sh" to test that the HPE Bare Metal service
| |     .yml file points to the expected OS image on the web server with the expected OS image
| |     size and signature.
| | (3) Add the Bare Metal Service file ($GLM_YML_SERVICE_FILE) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe-gl-intg.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| | (4) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
EOF

exit 0
