#!/usr/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)

echo -e "${bold}Script started${normal}"
echo
echo           "-------------------------"
echo -e "${bold}1 - Creating loop devices${normal}"
echo           "-------------------------"
for ind in {0..3} 
do
    dd if=/dev/zero of=/dev/disk${ind} bs=200M count=1
    losetup /dev/loop${ind} /dev/disk${ind}
    echo -e "# ${bold}Device loop${ind} created${normal}"
done

echo
echo           "------------------"
echo -e "${bold}2 - Creating RAIDs${normal}"
echo           "------------------"
cp /dev/disk0 /dev/disk1
cp /dev/disk2 /dev/disk3

echo "yes" | mdadm --create /dev/md0 --level=0 --raid-devices=2 /dev/loop0 /dev/loop1
echo -e "${bold}# RAID0 is created from /dev/loop0 and /dev/loop1${normal}" 
mdadm -D /dev/md0
echo 
echo "yes" | mdadm --create /dev/md1 --level=1 --raid-devices=2 /dev/loop2 /dev/loop3
echo -e "${bold}# RAID1 is created from /dev/loop2 and /dev/loop3${normal}"
mdadm -D /dev/md1


echo
echo           "--------------------------------------------------------"
echo -e "${bold}3 - Creating volume group on RAIDs /dev/md0 and /dev/md1${normal}"
echo           "--------------------------------------------------------"
echo -e "${bold}# Initializing phisical volumes${normal}"
pvcreate /dev/md0
pvcreate /dev/md1
echo
echo -e "${bold}# Initializing volume group${normal}"
vgcreate FIT_vg /dev/md0 /dev/md1
vgdisplay FIT_vg 

echo
echo           "---------------------------------------------------"
echo -e "${bold}4 - Creating logical columes on volume group FIT_vg${normal}"
echo           "---------------------------------------------------"
echo -e "${bold}# Creating 1 logical volume${normal}"
lvcreate FIT_vg -n FIT_lv1 -L100M
lvdisplay /dev/FIT_vg/FIT_lv1
echo
echo -e "${bold}# Creating 2 logical volume${normal}"
lvcreate FIT_vg -n FIT_lv2 -L100M
lvdisplay /dev/FIT_vg/FIT_lv2

echo
echo           "---------------------------------------"
echo -e "${bold}5 - Creating EXT4 filesystem on FIT_lv1${normal}"
echo           "---------------------------------------"
mkfs.ext4 /dev/FIT_vg/FIT_lv1

echo
echo           "--------------------------------------"
echo -e "${bold}6 - Creating XFS filesystem on FIT_lv2${normal}"
echo           "--------------------------------------"
mkfs.xfs /dev/FIT_vg/FIT_lv2

echo
echo           "------------------------------------------------------------"
echo -e "${bold}7 - Mounting FIT_lv1 to /mnt/test1 and FIT_lv2 to /mnt/test2${normal}"
echo           "------------------------------------------------------------"
echo "${bold}# Creating direcotry /mnt/test1${normal}"
mkdir /mnt/test1
ls -la /mnt/ | grep test1
echo "${bold}# Mounting to /mnt/test1${normal}"
mount /dev/FIT_vg/FIT_lv1 /mnt/test1
echo
echo "${bold}# Creating direcotry /mnt/test2${normal}"
mkdir /mnt/test2
ls -la /mnt/ | grep test2
echo "${bold}# Mounting to /mnt/test2${normal}"
mount /dev/FIT_vg/FIT_lv2 /mnt/test2 
mount -l | grep /mnt/test

echo
echo           "-------------------------------------------"
echo -e "${bold}8 - Resizing FIT_lv1 to all avaliable space${normal}"
echo           "-------------------------------------------"
lvextend -l 100%FREE /dev/FIT_vg/FIT_lv1
echo -e "${bold}Resizing filesystem on FIT_lv1${normal}"
umount /dev/FIT_vg/FIT_lv1
e2fsck -f /dev/FIT_vg/FIT_lv1
resize2fs /dev/FIT_vg/FIT_lv1
mount /dev/FIT_vg/FIT_lv1 /mnt/test1
df -h | grep "/mnt/test1"


echo           "---------------------"
echo -e "${bold}9 - Creating big file${normal}"
echo           "---------------------"
dd if=/dev/urandom of=/mnt/test1/big_file bs=300M count=10
ls -lh /mnt/test1/big_file
echo -e "${bold}Creating checksum${normal}"
sha512sum /mnt/test1/big_file

echo
echo           "----------------------------"
echo -e "${bold}10 - Emulation of disk fault${normal}"
echo           "----------------------------"
echo "${bold}# Creating loop5 device${normal}"
dd if=/dev/zero of=/dev/disk5 bs=200M count=1
losetup /dev/loop5 /dev/disk5
echo "${bold}# Degradating loop2${normal}"
mdadm --manage /dev/md1 --fail /dev/loop2
echo "${bold}# Removing loop2${normal}"
mdadm --manage /dev/md1 --remove /dev/loop2
echo  "${bold}# Adding loop5${normal}"
mdadm --manage /dev/md1 --add /dev/loop5
mdadm --detail /dev/md1