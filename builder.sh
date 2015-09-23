#!/bin/sh

# create partition XXX, need cleaner alternative
fdisk /dev/xvdb <<EOF
n
p
1



w
EOF

## format as ext4 

mkfs.ext4 /dev/xvdb1
mount /dev/xvdb1 /mnt/
mkdir /mnt/etc

export ROOT_UUID=$(blkid /dev/xvdb1 -o udev|grep ID_FS_UUID=|awk -F= '{print $2}')
cat << EOT >/mnt/etc/fstab
UUID=$ROOT_UUID       /                   ext4         defaults        1 1
tmpfs                                           /dev/shm            tmpfs        defaults        0 0
devpts                                          /dev/pts            devpts       gid=5,mode=620  0 0
sysfs                                           /sys                sysfs        defaults        0 0
proc                                            /proc               proc         defaults        0 0
EOT

yum --releasever=6 --installroot=/mnt/ -y groupinstall Base

cat <<EOT >/mnt/etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
NETWORKING_IPV6=no
IPV6INIT=no
EOT
cat <<EOT >/mnt/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE="eth0"
NM_CONTROLLED="no"
ONBOOT="yes"
BOOTPROTO="dhcp"
EOT

echo "sysctl.conf:net.ipv6.conf.all.disable_ipv6 = 1" >> /mnt/etc/sysctl.conf

CHROOT_KERNEL=`yum --installroot=/mnt/ install kernel | awk '/kernel/ {print $2}' | cut -c 8-`

cat <<EOT > /mnt/boot/grub/grub.conf
default=0
timeout=0
hiddenmenu

title CentOS ($CHROOT_KERNEL)
    root (hd0,0)
    kernel /boot/vmlinuz-$CHROOT_KERNEL ro root=UUID=$ROOT_UUID rd_NO_LUKS rd_NO_LVM LANG=en_US.UTF-8 rd_NO_MD console=ttyS0,115200 crashkernel=auto SYSFONT=latarcyrheb-sun16  KEYBOARDTYPE=pc KEYTABLE=us rd_NO_DM
    initrd /boot/initramfs-$CHROOT_KERNEL.img
EOT

ln -s /boot/grub/grub.conf /mnt/boot/grub/menu.lst

MAKEDEV -d /mnt/dev -x console
MAKEDEV -d /mnt/dev -x null
MAKEDEV -d /mnt/dev -x zero

mount -o bind /dev /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts
mount -o bind /dev/shm /mnt/dev/shm
mount -o bind /proc /mnt/proc
mount -o bind /sys /mnt/sys

cp /etc/resolv.conf /mnt/etc/resolv.conf

#timezone to UTC
cp /mnt/usr/share/zoneinfo/UTC /mnt/etc/localtime

### improve root prompt
cat <<EOF > /mnt/root/.bash_profile
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
     . ~/.bashrc
fi
EOF

cat <<EOF > /mnt/root/.bashrc
# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi
EOF

### run from inside the chroot ###

cat <<ENDOF > /mnt/tmp/script.sh

yum install -y epel-release
yum remove -y cpuspeed abrt* at hal* iptables-ipv6 irqbalance kexec-tools psacct quota sendmail smartmontools rng-tools mdadm
yum install -y openssh-server yum-plugin-fastestmirror e2fsprogs dhclient vi grub sudo cloud-init cloud-utils cloud-utils-growpart dracut-modules-growroot

chkconfig ntpd on

cat <<EOT > /etc/cloud/cloud.cfg.d/06_growpart.cfg
#!/bin/sh

growpart:
  mode: auto
  devices: ['/']
  ignore_growroot_disabled: false
  resize_rootfs: True
EOT

## keep the root user (this should be disabled in a default ami)
sed -i 's/disable_root: 1/disable_root: 0/' /etc/cloud/cloud.cfg
## you must not have any error from dracut !
dracut -f '' $CHROOT_KERNEL

grub-install /dev/xvdb
grub --batch <<EOT
device (hd0) /dev/xvdb
root (hd0,0)
setup (hd0)
quit
EOT

touch /.autorelabel
yum clean all
exit 0
ENDOF

chroot /mnt /bin/sh /tmp/script.sh

rm -f /mnt/tmp/script.sh
rm -f /mnt/root/.bash_history
rm -f /mnt/var/log/yum.log
rm -f /mnt/etc/resolv.conf
rm -rf /mnt/tmp/*
> /mnt/var/log/messages

umount /mnt/dev/shm
umount /mnt/dev/pts
umount /mnt/dev
umount /mnt/proc
umount /mnt/sys
umount /mnt

