#!/bin/bash -x
# (C) Copyright 2018-2022, 2024-2025 Hewlett Packard Enterprise Development LP

# This is the top-level build script that will take an Ubuntu/Debian install ISO and
# generate an Ubuntu/Debian service.yml file that can be imported as a Host OS into
# a Bare Metal portal.

# hpe-build-image-and-service.sh does the following steps:
# * process command line arguments.
# * Customize the Ubuntu/Debian .ISO so that it works for Bare Metal.  Run: hpe-image-build.sh.
# * Generate Bare Metal service file that is specific to $DISTRO_VER. Run: hpe-service-build.sh.

# hpe-build-image-and-service.sh usage:
# hpe-build-image-and-service.sh -i <distro-iso-filename> -o <hpe-custom-distro-tar>
#    -v <distro-version-number> -p <image-url-prefix> -s <hpe-yml-service-file>

# command line options         | Description
# ---------------------------- | -----------
# -i <distro-iso-filename>     | local filename of the standard Ubuntu/Debian .ISO file
#                              | that was already downloaded. Used as input file.
# ---------------------------- | -----------
# -v <distro-version-number>   | a x.y Ubuntu/Debian version number.  Example: -v 12.5
# ---------------------------- | -----------
# -n <distro-version-name>     | Distro name: Ubuntu or Debian
# ---------------------------- | -----------
# -r <rootpw>                  | set the Ubuntu/Debian OS root password
# ---------------------------- | -----------
# -o <hpe-custom-distro-tar>   | local filename of the Bare Metal modified Ubuntu/Debian .tar file
#                              | that will be output by the script.  This file should
#                              | be uploaded to your web server.
# ---------------------------- | -----------
# -p <image-url-prefix>        | the beginning of the image URL (on your web server).
#                              | Example: -p http://192.168.1.131.  The Bare Metal service .YML
#                              | will assume that the image file will be available at
#                              | a URL constructed with <image-url-prefix>/<hpe-custom-distro-tar>.
# ---------------------------- | -----------
# -s <hpe-yml-service-file>    | local filename of the Bare Metal .YML service file that
#                              | will be output by the script.  This file should
#                              | be uploaded to the Bare Metal portal.
# ---------------------------- | -----------
# -x <skip-test>               | [optional] Skip the test with "-x true"
#                              | By default this script will run the test "hpe-test-service-image.sh"
#                              | script to verify that the upload was correct, and the size and checksum
#                              | of the ISO matches what is defined in the YML.
# ---------------------------- | -----------

# NOTE: Make sure to upload the <hpe-custom-distro-tar> .ISO file to your web server to make it accessible
# at this constructed URL: # <image-url-prefix>/<hpe-custom-distro-tar>

# If the image URL can not be constructed with this simple mechanism, then you probably need to customize
# this script for a more complex URL construction.

# This script calls `hpe-image-build.sh`, which needs the following packages to be installed on Debian/Ubuntu:
# Command: `sudo apt install xorriso isomd5sum isolinux aptly wget`

# To run the test script: hpe-test-service-image.sh
#   By default this script will run the test script "hpe-test-service-image.sh"
#   to verify that the upload was correct, and the size and checksum of the
#   ISO matches what is defined in the YML.
#   Example:
#     ./hpe-build-image-and-service.sh        \
#     -i images/debian-12.5.0-amd64-DVD-1.iso \
#     -v 12.5                                 \
#     -r PASSWORD                             \
#     -p https://10.152.3.96                  \
#     -o images/debian-12.5.0-amd64-GLM.iso   \
#     -s images/debian-12.5.0-amd64-GLM.yml

set -euo pipefail

# ==================================================================================
# Prerequisites:
# ==================================================================================
# Required parameters for Image Web Server and test script "hpe-test-service-image.sh"
#   WEB_SERVER_IP: IP address of web server to transfer ISO to (via SSH)
#   REMOTE_PATH:   Path on web server to copy files to
#   SSH_USER:      Username for SSH transfer
#   Note: Add your Linux test machine's SSH key to the Web Server
WEB_SERVER_IP="10.152.3.96"
REMOTE_PATH="/var/www/images/"
SSH_USER_NAME="root"
# ==================================================================================

# other required parameters
DISTRO_ISO_FILENAME=""
GLM_CUSTOM_DISTRO_TAR=""
DISTRO_VER=""
DISTRO_NAME=""
DISTRO_ROOTPW=""
IMAGE_URL_PREFIX=""
GLM_YML_SERVICE_FILE=""
GLM_YML_SERVICE_TEMPLATE=""
SKIP_TEST=""

while getopts "i:v:n:r:o:p:s:x:" opt
do
    case $opt in
        # required parameters
        i) DISTRO_ISO_FILENAME=$OPTARG ;;
        v) DISTRO_VER=$OPTARG ;;
        n) DISTRO_NAME=$OPTARG ;;
        r) DISTRO_ROOTPW=`openssl passwd -6 -salt xyz $OPTARG` ;;
        o) GLM_CUSTOM_DISTRO_TAR=$OPTARG ;;
        p) IMAGE_URL_PREFIX=$OPTARG ;;
        s) GLM_YML_SERVICE_FILE=$OPTARG ;;
        x) SKIP_TEST=$OPTARG ;;
        *) echo "ERROR invalid parameter."; exit 1 ;;
     esac
done

# Check that required parameters exist.
if [ -z "$DISTRO_ISO_FILENAME" -o \
     -z "$GLM_CUSTOM_DISTRO_TAR" -o \
     -z "$DISTRO_VER" -o \
     -z "$DISTRO_NAME" -o \
     -z "$DISTRO_ROOTPW" -o \
     -z "$IMAGE_URL_PREFIX" -o \
     -z "$GLM_YML_SERVICE_FILE" ]; then
  echo "script usage: $0 -i distro-iso -v distro-version -n distro-name -r distro-rootpw" >&2
  echo "              -o hpe-custom-distro-tar -p http-prefix -s hpe-yml-service-file" >&2
  exit 1
fi

if [[ ! -f $DISTRO_ISO_FILENAME ]]; then
  echo "ERROR missing ISO image file $DISTRO_ISO_FILENAME"
  exit 1
fi

# The clean function cleans up any lingering files
# that might be present when the script exits.
clean() {
  if [ ! -z "$GLM_YML_SERVICE_TEMPLATE" ]; then
    rm -f $GLM_YML_SERVICE_TEMPLATE
  fi
}

# By default this script will run the test "hpe-test-service-image.sh" script
# to verify that the upload was correct, and the size and checksum of the
# ISO matches what is defined in the YML.
# Note: Set the Web Server related parameters at the top
#   User may verify SCP transfer using following commands:
#     $ echo bye | sftp -b - ${SSH_USER_NAME}@${WEB_SERVER_IP}
#     $ rsync -av --dry-run ${SOURCE} ${DESTINATION}
run_test() {
if [ "${SKIP_TEST}" != "true" ]; then
  # Run the test by default
   echo -e "\nCopying .tar file to the web server..."
   SOURCE="${GLM_CUSTOM_DISTRO_TAR}"
   DESTINATION="${SSH_USER_NAME}@${WEB_SERVER_IP}:${REMOTE_PATH}"
   echo "scp ${SOURCE} ${DESTINATION}"
   scp ${SOURCE} ${DESTINATION}
   if [ $? -ne 0 ]; then echo "ERROR scp failed to copy image"; exit 1; fi
   echo -e "\nRunning the test "hpe-test-service-image.sh"..."
   echo "./hpe-test-service-image.sh ${GLM_YML_SERVICE_FILE}"
   ./hpe-test-service-image.sh ${GLM_YML_SERVICE_FILE}
fi
}

# Set a trap to call the clean function on exit
trap clean EXIT

# if the Bare Metal customized DISTRO .ISO has not already been generated.
if [ ! -f $GLM_CUSTOM_DISTRO_TAR ]; then
   # Customize the DISTRO .ISO so that it works for Bare Metal.
   GEN_IMAGE="sudo ./hpe-image-build.sh \
      -i $DISTRO_ISO_FILENAME \
      -o $GLM_CUSTOM_DISTRO_TAR \
      -v $DISTRO_VER \
      -n $DISTRO_NAME"
   echo $GEN_IMAGE
   $GEN_IMAGE
fi

GLM_YML_SERVICE_TEMPLATE=$(mktemp /tmp/hpe-service.cfg.XXXXXXXXX)
sed -e "s/%OS_VERSION%/$DISTRO_VER/g" hpe-service.yml.template > $GLM_YML_SERVICE_TEMPLATE

# set the root password in the KS configuration file (here, hpe-preseed.cfg.template)
sed -i "s'%ROOTPW%'$DISTRO_ROOTPW'g" hpe-preseed.cfg.template

# Generate HPE Bare Metal service file.
YYYYMMDD=$(date '+%Y%m%d')
GEN_SERVICE="./hpe-service-build.sh \
  -s $GLM_YML_SERVICE_TEMPLATE \
  -o $GLM_YML_SERVICE_FILE \
  -c linux \
  -f $DISTRO_NAME \
  -v $DISTRO_VER-$YYYYMMDD-BYOI \
  -u $IMAGE_URL_PREFIX/$GLM_CUSTOM_DISTRO_TAR \
  -d $DISTRO_ISO_FILENAME \
  -i $GLM_CUSTOM_DISTRO_TAR \
  -t hpe-preseed.cfg.template \
  -t hpe-cloud-init.template \
  -t hpe-apt-cloud-init.list.template"
echo $GEN_SERVICE
$GEN_SERVICE

# unset the root password in the KS configuration file (here, hpe-preseed.cfg.template)
sed -i '/d-i passwd\/root-password-crypted password/c\d-i passwd\/root-password-crypted password %ROOTPW%' hpe-preseed.cfg.template

# By default run the test script "hpe-test-service-image.sh" to verify ISO image
run_test

# print out instructions for using this image & service
NOTE="| |     
| |     IMPORTANT: Use the test (hpe-test-service-image.sh) script to verify that
| |                the ISO upload was correct, and the size and checksum of the ISO
| |                match what is defined in the YML.
| |"

cat << EOF
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal $DISTRO_NAME service/image
| | that consists of the following 2 new files:
| |     $GLM_CUSTOM_DISTRO_TAR
| |     $GLM_YML_SERVICE_FILE
| |
| | To use this new Bare Metal $DISTRO_NAME service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file ($GLM_CUSTOM_DISTRO_TAR)
| |     to your web server ($IMAGE_URL_PREFIX) such that the file can be downloaded
| |     from the following URL: $IMAGE_URL_PREFIX/$GLM_CUSTOM_DISTRO_TAR
`if [ "${SKIP_TEST}" == "true" ]; then echo "${NOTE}"; echo ; else echo "| |"; fi`
| | (2) Add the Bare Metal Service file ($GLM_YML_SERVICE_FILE) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
EOF

exit 0
