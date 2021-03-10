#!/bin/sh
# to be run as root

# handle options
while getopts ":r:b:h:u:o:t:s:w:c:m" o; do case "${o}" in
    r) devroot=${OPTARG} ;;
    b) devboot=${OPTARG} ;;
    h) devhome=${OPTARG} ;;
    u) devusr=${OPTARG} ;;
    o) devopt=${OPTARG} ;;
    t) devtmp=${OPTARG} ;;
    s) devsrc=${OPTARG} ;;
    w) devswap=${OPTARG} ;;
    c) sourceslist=${OPTARG} ;;
    m) md5sums=${OPTARG} ;;
    *) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

export LFS=/mnt/lfs

# error message
error() {
    printf "ERROR:\\n%s\\n" "$1"; exit
}

# set default arguments
if [ -z $sourceslist ]; then
    sourceslist="http://www.linuxfromscratch.org/lfs/view/stable/wget-list"
    md5sums="http://www.linuxfromscratch.org/lfs/view/stable/md5sums"
fi

# create and mount file systems
export LFS=/mnt/lfs
mount $devroot $LFS
if [ ! -z $devroot ]; then
    mkdir -v -p $LFS
    mkfs.ext4 $devroot
    mount $devroot $LFS
else
    error "No block device for root partition."
fi
mount $devboot $LFS
if [ ! -z $devboot ]; then
    mkdir -v -p $LFS/boot
    mkfs.ext2 $devboot
    mount $devboot $LFS/boot
# else
#     error "No block device for boot partition."
fi
if [ ! -z $devhome ]; then
    mkdir -v -p $LFS/home
    mkfs.ext4 $devhome
    mount $devhome $LFS/home
fi
if [ ! -z $devusr ]; then
    mkdir -v -p $LFS/usr
    mkfs.ext4 $devusr
    mount $devusr $LFS/usr
fi
if [ ! -z $devopt ]; then
    mkdir -v -p $LFS/opt
    mkfs.ext4 $devopt
    mount $devopt $LFS/opt
fi
if [ ! -z $devtmp ]; then
    mkdir -v -p $LFS/tmp
    mkfs.ext4 $devtmp
    mount $devtmp $LFS/tmp
fi
if [ ! -z $devsrc ]; then
    mkdir -v -p $LFS/usr/src
    mkfs.ext4 $devsrc
    mount $devsrc $LFS/usr/src
fi
if [ ! -z $devswap ]; then
    mkswap $devswap
    /sbin/swapon $devswap
fi

# download and/or check sources
mkdir -v -p $LFS/sources
chmod -v a+wt $LFS/sources
wget -O $LFS/sources/wget-list $sourceslist
wget \
    --input-file=$LFS/sources/wget-list \
    --continue \
    --directory-prefix=$LFS/sources
wget -O $LFS/sources/md5sums $md5sums
pushd $LFS/sources
md5sum -c md5sums || error "md5sum failed for one or more packages."
popd
