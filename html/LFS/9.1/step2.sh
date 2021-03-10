#!/bin/sh
# to be run as root

export LFS=/mnt/lfs

# create tools directory
mkdir -v -p $LFS/tools
ln -sv $LFS/tools /

# create LFS user
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
passwd lfs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

# create .bash_profile
cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
chown lfs:lfs /home/lfs/.bash_profile

# create .bashrc
cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF
chown lfs:lfs /home/lfs/.bashrc
