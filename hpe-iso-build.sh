#!/bin/bash
# (C) Copyright 2021-2022,2024 Hewlett Packard Enterprise Development LP
#
# This script will repack Ubuntu/Debian .ISO file for a GLM
# Ubuntu/Debian install service that uses Virtual Media
# to get the install started.

# The following changes are being made to the Ubuntu/Debian .ISO:
#   (1) configure to use a preseed file on the iLO vmedia-cd
#   (2) setup for a text based install (versus a GUI install)
#   (3) set up the console to the iLO serial port (/dev/ttyS1)

# The Ubuntu/Debian .ISO is configured to use a preseed file on the iLO
# vmedia-cd by adding the 'inst.ks=hd:sr0:/hpe-preseed.cfg.template' option in
# GRUB (used in UEFI) and isolinux (used in BIOS) configuration
# files. This option configures Ubuntu/Debian installer to pull the
# preseed file from the root of the cdrom at /hpe-preseed.cfg.template.  This
# preseed option is setup by modifying the following files
# on the .ISO:
#   isolinux/isolinux.cfg for BIOS
#   EFI/BOOT/grub.cfg for UEFI

# Usage:
#  hpe-iso-build.sh -i <distro.iso> -o <hpe-custom-distro.iso>

# command line options            | Description
# ------------------------------- | -----------
# -i <distro.iso>                 | Input Ubuntu/Debian .ISO filename
# -o <hpe-custom-distro.iso>      | Output GLM Ubuntu/Debian .ISO file
# -n <distro-name>                | Distro Name: Ubuntu or Debian

# TODO This script is unusual.  In order to inject the hpe-preseed_setup.cfg
# file into the .iso, it does (mount iso ... cp preseed ... xorriso).  But then
# right after that it uses another technique to update the UEFI configuration
# file (xorriso -extract ${UEFI_CFG_FILE} ... xorriso -update ${UEFI_CFG_FILE}).
# We should use one technique or the other but not both!

set -exuo pipefail

# make sure we have enough permissions to mount .iso, etc
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit -1
fi

# check to make sure we have the required tools called within this script
for i in xorriso implantisomd5 md5sum aptly wget
do
  which $i > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo "$i not found. Please install."
    exit -1
  fi
done

if [ ! -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]
then
  echo "/usr/lib/ISOLINUX/isohdpfx.bin not found. Please install 'isolinux' package."
  exit -1
fi

UEFI_ORIG_CFG_FILE=""
INPUT_ISO_FILENAME=""
CUSTOM_ISO_FILENAME=""
DISTRO_NAME=""
# parse command line parameters
while getopts "i:o:n:" opt
do
    case $opt in
        i) INPUT_ISO_FILENAME=$OPTARG
            if [[ ! -f $INPUT_ISO_FILENAME ]]
            then
                echo "ERROR missing image file $INPUT_ISO_FILENAME"
                exit -1
            fi
            ;;
        o) CUSTOM_ISO_FILENAME=$OPTARG ;;
        n) DISTRO_NAME=${OPTARG^^} ;;
    esac
done

if [ -z "$INPUT_ISO_FILENAME" -o -z "$CUSTOM_ISO_FILENAME" -o -z "$DISTRO_NAME" ]; then
   echo "Usage: $0 -i <distro.iso> -o <hpe-custom-distro.iso> -n <distro-name>"
   exit 1
fi

# Generate unique ID for use as the uploaded file name.
ID=$RANDOM
YYYYMMDD=$(date '+%Y%m%d')

# Unpack the OS .ISO, inject the files, and pack it again
#   Inject following files:
#     1. hpe-preseed_setup.cfg
MNT_POINT=/media/$DISTRO_NAME/
mkdir -p $MNT_POINT
mkdir -p /tmp/custom_iso
ls -lrt $INPUT_ISO_FILENAME
md5sum $INPUT_ISO_FILENAME
sudo mount -t iso9660 -o loop $INPUT_ISO_FILENAME $MNT_POINT
cd $MNT_POINT
tar cf - . | (cd /tmp/custom_iso; tar xfp -)
ls -lrt /tmp/custom_iso/
cd -
sudo cp hpe-preseed_setup.cfg /tmp/custom_iso/
sudo umount $MNT_POINT

if [ "${DISTRO_NAME^^}" == "DEBIAN" ]; then

xorriso -as mkisofs -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 \
  -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
  -isohybrid-gpt-basdat -o $INPUT_ISO_FILENAME /tmp/custom_iso/

fi

if [ "${DISTRO_NAME^^}" == "UBUNTU" ]; then

# https://www.pugetsystems.com/labs/hpc/ubuntu-22-04-server-autoinstall-iso/

# I got this xorriso incantation from Step 5) Generate a new Ubuntu 22.04 server autoinstall ISO
# of the article with a few modifications

# But I did not do Step 2) Unpack files and partition images from the Ubuntu 22.04 live server ISO

# TODO find a complete working solution

xorriso -as mkisofs -r \
  --grub2-mbr ../BOOT/1-Boot-NoEmul.img \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../BOOT/2-Boot-NoEmul.img \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c '/boot.catalog' \
  -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:::' \
  -no-emul-boot \
  -isohybrid-gpt-basdat -o $INPUT_ISO_FILENAME /tmp/custom_iso/

fi

ls -lrt $INPUT_ISO_FILENAME
md5sum $INPUT_ISO_FILENAME
sudo rm -rf /tmp/custom_iso/

# Locate the GRUB Configuration File
UEFI_CFG_FILE=boot/grub/grub.cfg  # For Ubuntu/Debian

# extract the ${UEFI_CFG_FILE} from the .ISO
xorriso -osirrox on -indev $INPUT_ISO_FILENAME -extract ${UEFI_CFG_FILE} ${UEFI_CFG_FILE}

if [ ! -f "${UEFI_CFG_FILE}" ]; then
  echo "did not find ${UEFI_CFG_FILE} on <distro-iso-filename>"
  exit -1
fi

# Make the extracted file writable (xorriso makes it read-only when extracted)
chmod -R u+w boot # for Ubuntu/Debian based OS

# The clean function cleans up any lingering files
# that might be present when the script exits.
clean() {
  # remove entire $UEFI_CFG_FILE directory & files
  if [ -d "boot" ]; then
     rm -rf boot
  fi
}

trap clean EXIT

if [ ! -f "${UEFI_CFG_FILE}" ]; then
  echo "did not find ${UEFI_CFG_FILE} on <distro-iso-filename>"
  exit -1
fi

# save the original grub.cfg files
UEFI_ORIG_CFG_FILE=$(mktemp /tmp/grub.cfg.XXXXXXXXX)
cp ${UEFI_CFG_FILE} $UEFI_ORIG_CFG_FILE

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo $UEFI_ORIG_CFG_FILE
cat $UEFI_ORIG_CFG_FILE
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

###################################################
# start the UEFI_CFG_FILE file modifications

# set the the default timeout to 0 seconds
sed -i '1itimeout=0' ${UEFI_CFG_FILE}

# change the menu selection to the 1st entry
sed -i '2iprompt=1' ${UEFI_CFG_FILE}

# tell the .ISO to run the hpe-preseed_setup.cfg as the
# thing that kickstarts the automated install
# also setup the serial console to ttyS1 (iLO serial port) with 115200 baud
sed -i -E "s/(.*)(\/vmlinuz)(.*)/\1\2 auto=true preseed\/file=\/cdrom\/hpe-preseed_setup.cfg console=ttyS1,115200 priority=critical BOOT_DEBUG=2 \3/" ${UEFI_CFG_FILE}

# remove the 'quiet' option so the user can watch kernel loading
# and use to triage any problems
sed -i "s/quiet//" ${UEFI_CFG_FILE}

# report on the changes to isolinux.org
echo "===================================================="
echo diff -u $UEFI_ORIG_CFG_FILE ${UEFI_CFG_FILE}
set +e
diff -u $UEFI_ORIG_CFG_FILE ${UEFI_CFG_FILE}
set -e
echo "===================================================="

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo $UEFI_CFG_FILE
cat $UEFI_CFG_FILE
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

# end the UEFI_CFG_FILE file modifications
###################################################

# Create the Ubuntu/Debian .ISO file

echo
echo Creating ${CUSTOM_ISO_FILENAME}

# Create new ISO file with modified CFG
xorriso -indev $INPUT_ISO_FILENAME -outdev ${CUSTOM_ISO_FILENAME} -boot_image isohybrid keep -update ${UEFI_CFG_FILE} ${UEFI_CFG_FILE}

# Implant an MD5 checksum into the image. Without performing this step,
# image verification check (the rd.live.check option in the boot
# loader configuration) will fail and you will not be able to continue
# with the installation.
MD5_ISO="implantisomd5 ${CUSTOM_ISO_FILENAME}"
echo $MD5_ISO
$MD5_ISO
