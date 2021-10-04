#!/bin/sh

USERHOME=$1
SIZE=$2

zfs create -omountpoint=/encrypted tank/encrypted
zfs create tank/encrypted/keys
zfs create -omountpoint=none tank/encrypted/zvols
zfs create -ocompression=on tank/encrypted/zvols/${USERHOME}
zfs create -V ${SIZE}G tank/encrypted/zvols/${USERHOME}/disk0
zfs create -V ${SIZE}G tank/encrypted/zvols/${USERHOME}/disk1

zfs create tank/encrypted/keys/${USERHOME}
dd if=/dev/random of=/encrypted/keys/${USERHOME}/disk0 bs=64 count=1
dd if=/dev/random of=/encrypted/keys/${USERHOME}/disk1 bs=64 count=1
geli init -s 4096 -K /encrypted/keys/${USERHOME}/disk0 /dev/zvol/tank/encrypted/zvols/${USERHOME}/disk0
geli init -s 4096 -K /encrypted/keys/${USERHOME}/disk1 /dev/zvol/tank/encrypted/zvols/${USERHOME}/disk1

geli attach -k /encrypted/keys/${USERHOME}/disk0 /dev/zvol/tank/encrypted/zvols/${USERHOME}/disk0
geli attach -k /encrypted/keys/${USERHOME}/disk1 /dev/zvol/tank/encrypted/zvols/${USERHOME}/disk1

zpool create ${USERHOME}-home raidz /dev/zvol/tank/encrypted/zvols/${USERHOME}/disk0.eli /dev/zvol/tank/encrypted/zvols/${USERHOME}/disk1.eli
