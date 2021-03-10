#!/bin/sh
# to be run as root

# prepare virtual kernel file systems
mkdir -pv $LFS/{dev,proc,sys,run}

# create initial device nodes
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3

# mount and populate /dev
mount -v --bind /dev $LFS/dev

# mount virtual kernel file systems
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

echo "finished
run the following as root:
    chroot "\$LFS" /tools/bin/env -i \\
    HOME=/root                  \\
    TERM="\$TERM"                \\
    PS1='(lfs chroot) \u:\w\$ ' \\
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \\
    /tools/bin/bash --login +h"
