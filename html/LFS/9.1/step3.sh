#!/bin/sh
# to be run as lfs

# todo:
# help dialog
# SBU time
# add lfs to sudoers
# traps to delete incomplete build dir

# handle options
while getopts ":d" o; do case "${o}" in
    d) delayall=true ;;
    t) testall=true ;;
    *) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

export LFS=/mnt/lfs
export sourcesdir=$LFS/sources

promptcores(){
    echo -n 'Enter number of CPU cores or leave blank for safe defaults: '
    read cores
    export MAKEFLAGS="-j ${cores:-1}"
    echo "using $cores cores"
}

saveprogress(){
    echo $1 > ~/.lfsresume
}

delay(){
    echo 'press any key to continue'
    read keypress
}

deletesourcesandsave(){
    [ -z $delayall ] || delay
    rm -rfv ${sourcesdir}/$1
    saveprogress ${FUNCNAME[1]}
}

sanitycheck(){
    echo 'performing sanity check'
    echo 'int main(){}' > dummy.c
    $LFS_TGT-gcc dummy.c
    readelf -l a.out | grep ': /tools'
    delay
    rm -v dummy.c a.out
}

binutils_pass1_(){
    pkgarchive=binutils-2.34.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    mkdir -v build
    cd build
    ../configure --prefix=/tools            \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror
    make
    case $(uname -m) in
        x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
    esac
    make install
    ###
    deletesourcesandsave $pkgdir
}

gcc_pass1_(){
    pkgarchive=gcc-9.2.0.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    tar -xvf ../mpfr-4.0.2.tar.xz
    mv -v mpfr-4.0.2 mpfr
    tar -xvf ../gmp-6.2.0.tar.xz
    mv -v gmp-6.2.0 gmp
    tar -xvf ../mpc-1.1.0.tar.gz
    mv -v mpc-1.1.0 mpc
    for file in gcc/config/{linux,i386/linux{,64}}.h
    do
      cp -uv $file{,.orig}
      sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
          -e 's@/usr@/tools@g' $file.orig > $file
      echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
      touch $file.orig
    done
    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
     ;;
    esac
    mkdir -v build
    cd build
    ../configure                                       \
        --target=$LFS_TGT                              \
        --prefix=/tools                                \
        --with-glibc-version=2.11                      \
        --with-sysroot=$LFS                            \
        --with-newlib                                  \
        --without-headers                              \
        --with-local-prefix=/tools                     \
        --with-native-system-header-dir=/tools/include \
        --disable-nls                                  \
        --disable-shared                               \
        --disable-multilib                             \
        --disable-decimal-float                        \
        --disable-threads                              \
        --disable-libatomic                            \
        --disable-libgomp                              \
        --disable-libquadmath                          \
        --disable-libssp                               \
        --disable-libvtv                               \
        --disable-libstdcxx                            \
        --enable-languages=c,c++
    make
    make install
    ###
    deletesourcesandsave $pkgdir
}

linuxapiheaders_(){
    pkgarchive=linux-5.5.3.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    make mrproper
    make headers
    cp -rv usr/include/* /tools/include
    ###
    deletesourcesandsave $pkgdir
}

glibc_(){
    pkgarchive=glibc-2.31.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    mkdir -v build
    cd build
    ../configure                             \
          --prefix=/tools                    \
          --host=$LFS_TGT                    \
          --build=$(../scripts/config.guess) \
          --enable-kernel=3.2                \
          --with-headers=/tools/include
    make
    make install
    sanitycheck
    ###
    deletesourcesandsave $pkgdir
}

libstdcxx_(){
    pkgarchive=gcc-9.2.0.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    mkdir -v build
    cd build
    ../libstdc++-v3/configure           \
        --host=$LFS_TGT                 \
        --prefix=/tools                 \
        --disable-multilib              \
        --disable-nls                   \
        --disable-libstdcxx-threads     \
        --disable-libstdcxx-pch         \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/9.2.0
    make
    make install
    ###
    deletesourcesandsave $pkgdir
}

binutils_pass2_(){
    pkgarchive=binutils-2.34.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    mkdir -v build
    cd build
    CC=$LFS_TGT-gcc                \
    AR=$LFS_TGT-ar                 \
    RANLIB=$LFS_TGT-ranlib         \
    ../configure                   \
        --prefix=/tools            \
        --disable-nls              \
        --disable-werror           \
        --with-lib-path=/tools/lib \
        --with-sysroot
    make
    make install
    make -C ld clean
    make -C ld LIB_PATH=/usr/lib:/lib
    cp -v ld/ld-new /tools/bin
    ###
    deletesourcesandsave $pkgdir
}

gcc_pass2_(){
    pkgarchive=gcc-9.2.0.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
      `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
    for file in gcc/config/{linux,i386/linux{,64}}.h
    do
      cp -uv $file{,.orig}
      sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
          -e 's@/usr@/tools@g' $file.orig > $file
      echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
      touch $file.orig
    done
    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
      ;;
    esac
    tar -xf ../mpfr-4.0.2.tar.xz
    mv -v mpfr-4.0.2 mpfr
    tar -xf ../gmp-6.2.0.tar.xz
    mv -v gmp-6.2.0 gmp
    tar -xf ../mpc-1.1.0.tar.gz
    mv -v mpc-1.1.0 mpc
    sed -e '1161 s|^|//|' \
        -i libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cc
    mkdir -v build
    cd build
    CC=$LFS_TGT-gcc                                    \
    CXX=$LFS_TGT-g++                                   \
    AR=$LFS_TGT-ar                                     \
    RANLIB=$LFS_TGT-ranlib                             \
    ../configure                                       \
        --prefix=/tools                                \
        --with-local-prefix=/tools                     \
        --with-native-system-header-dir=/tools/include \
        --enable-languages=c,c++                       \
        --disable-libstdcxx-pch                        \
        --disable-multilib                             \
        --disable-bootstrap                            \
        --disable-libgomp
    make
    make install
    ln -sv gcc /tools/bin/cc
    sanitycheck
    ###
    deletesourcesandsave $pkgdir
}

tcl_(){
    pkgarchive=tcl8.6.10-src.tar.gz
    pkgdir=${pkgarchive%%-src*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    cd unix
    ./configure --prefix=/tools
    make
    [ -z $testall ] || TZ=UTC make test
    make install
    chmod -v u+w /tools/lib/libtcl8.6.so
    make install-private-headers
    ln -sv tclsh8.6 /tools/bin/tclsh
    ###
    deletesourcesandsave $pkgdir
}

expect_(){
    pkgarchive=expect5.45.4.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    cp -v configure{,.orig}
    sed 's:/usr/local/bin:/bin:' configure.orig > configure
    ./configure --prefix=/tools       \
                --with-tcl=/tools/lib \
                --with-tclinclude=/tools/include
    make
    [ -z $testall ] || make test
    echo -n 'press any key to continue'
    delay
    make SCRIPTS="" install
    ###
    deletesourcesandsave $pkgdir
}

dejagnu_(){
    pkgarchive=dejagnu-1.6.2.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make install
    make check
    ###
    deletesourcesandsave $pkgdir
}

m4_(){
    pkgarchive=m4-1.4.18.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
    echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

ncurses_(){
    pkgarchive=ncurses-6.2.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sed -i s/mawk// configure
    ./configure --prefix=/tools \
                --with-shared   \
                --without-debug \
                --without-ada   \
                --enable-widec  \
                --enable-overwrite
    make
    make install
    ln -s libncursesw.so /tools/lib/libncurses.so
    ###
    deletesourcesandsave $pkgdir
}

bash_(){
    pkgarchive=bash-5.0.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools --without-bash-malloc
    make
    [ -z $testall ] || make tests
    make install
    ln -sv bash /tools/bin/sh
    ###
    deletesourcesandsave $pkgdir
}

bison_(){
    pkgarchive=bison-3.5.2.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

bzip2_(){
    pkgarchive=bzip2-1.0.8.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/tools install
    cp -v bzip2-shared /tools/bin/bzip2
    cp -av libbz2.so* /tools/lib
    ln -sv libbz2.so.1.0 /tools/lib/libbz2.so
    ###
    deletesourcesandsave $pkgdir
}

coreutils_(){
    pkgarchive=coreutils-8.31.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools --enable-install-program=hostname
    make
    [ -z $testall ] || make RUN_EXPENSIVE_TESTS=yes check
    make install
    ###
    deletesourcesandsave $pkgdir
}

diffutils_(){
    pkgarchive=diffutils-3.7.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

file_(){
    pkgarchive=file-5.38.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

findutils_(){
    pkgarchive=findutils-4.7.0.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

gawk_(){
    pkgarchive=gawk-5.0.1.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

gettext_(){
    pkgarchive=gettext-0.20.1.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --disable-shared
    make
    cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin
    ###
    deletesourcesandsave $pkgdir
}

grep_(){
    pkgarchive=grep-3.4.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

gzip_(){
    pkgarchive=gzip-1.10.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

make_(){
    pkgarchive=make-4.3.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools --without-guile
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

patch_(){
    pkgarchive=patch-2.7.6.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

perl_(){
    pkgarchive=perl-5.30.1.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth
    make
    cp -v perl cpan/podlators/scripts/pod2man /tools/bin
    mkdir -pv /tools/lib/perl5/5.30.1
    cp -Rv lib/* /tools/lib/perl5/5.30.1
    ###
    deletesourcesandsave $pkgdir
}

python_(){
    pkgarchive=Python-3.8.1.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sed -i '/def add_multiarch_paths/a \        return' setup.py
    ./configure --prefix=/tools --without-ensurepip
    make
    make install
    ###
    deletesourcesandsave $pkgdir
}

sed_(){
    pkgarchive=sed-4.8.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

tar_(){
    pkgarchive=tar-1.32.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

texinfo_(){
    pkgarchive=texinfo-6.7.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

xz_(){
    pkgarchive=xz-5.2.4.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/tools
    make
    [ -z $testall ] || make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

# prompt cores for build
promptcores

# attempt to resume incomplete build
tasks='start; binutils_pass1_; gcc_pass1_; linuxapiheaders_; glibc_; libstdcxx_; binutils_pass2_; gcc_pass2_; tcl_; expect_; dejagnu_; m4_; ncurses_; bash_; bison_; bzip2_; coreutils_; diffutils_; file_; findutils_; gawk_; gettext_; grep_; gzip_; make_; patch_; perl_; python_; sed_; tar_; texinfo_; xz_;'
[ -e ~/.lfsresume ] && read lastcomplete < ~/.lfsresume
eval ${tasks##*${lastcomplete:-start};}

echo 'finished
run the following as root:
chown -R root:root $LFS/tools'
