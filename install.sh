#! /bin/bash

# This is Krushn's Arch Linux Installation Script.
# Visit krushndayshmookh.github.io/krushn-arch for instructions.

echo "Krushn's Arch Installer"

# Set up network connection
read -p 'Are you connected to internet? [y/N]: ' neton
if ! [ $neton = 'y' ] && ! [ $neton = 'Y' ]
then 
    echo "Connect to internet to continue..."
    exit
fi

# Filesystem mount warning
echo "This script will create and format the partitions as follows:"
echo "/dev/sda1 - 512Mib will be mounted as /boot/efi"
echo "/dev/sda2 - 8GiB will be used as swap"
echo "/dev/sda3 - rest of space will be mounted as /"
read -p 'Continue? [y/N]: ' fsok
if ! [ $fsok = 'y' ] && ! [ $fsok = 'Y' ]
then 
    echo "Edit the script to continue..."
    exit
fi

# to create the partitions programatically (rather than manually)
# https://superuser.com/a/984637
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  +512M # 512 MB boot parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
  +8G # 8 GB swap parttion
  n # new partition
  p # primary partition
  3 # partion number 3
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

# Format the partitions
mkfs.btrfs /dev/sda3
mkfs.fat -F32 /dev/sda1

# Set up time
timedatectl set-ntp true

# Initate pacman keyring
pacman-key --init
pacman-key --populate archlinux
pacman-key --refresh-keys

# Mount the partitions
mount /dev/sda3 /mnt
mkdir -pv /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
mkswap /dev/sda2
swapon /dev/sda2

# Install Arch Linux
echo "Starting install.."
echo "Installing Arch Linux, " 
pacstrap /mnt base base-devel grub os-prober intel-ucode efibootmgr dosfstools ffmpeg git

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<EOF >> /mnt/root/settings.sh
#! /bin/bash
# Set date time
ln -sf /usr/share/zoneinfo/America/Detroit /etc/localtime
hwclock --systohc
# Set locale to en_US.UTF-8 UTF-8
sed -i '/en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
# Set hostname
echo "dataserver" >> /etc/hostname
echo "127.0.1.1 dataserver.localdomain  dataserver" >> /etc/hosts
# Generate initramfs
mkinitcpio -P
# Set root password
passwd dataserver
# Install bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg
# Create new user
useradd -m -G wheel,power,input,storage,uucp,network -s /usr/bin/sh media
sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers
echo "Set password for new user"
passwd password
sudo -u media git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u media makepkg -si
# Enable services
systemctl enable NetworkManager.service
exit
<<EOF
arch-chroot /mnt /bin/bash
sh /root/settings.sh
reboot
