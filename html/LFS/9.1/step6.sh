#!/tools/bin/bash
# to be run in chroot

# handle options
while getopts ":d" o; do case "${o}" in
    d) delayall=true ;;
    t) testall=true ;;
    *) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

export sourcesdir=/sources

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

linuxapiheaders_(){
    pkgarchive=linux-5.5.3.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    make mrproper
    make headers
    find usr/include -name '.*' -delete
    rm usr/include/Makefile
    cp -rv usr/include/* /usr/include
    ###
    deletesourcesandsave $pkgdir
}

man_pages_(){
    pkgarchive=man-pages-5.05.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    make install
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
    patch -Np1 -i ../glibc-2.31-fhs-1.patch
    # case $(uname -m) in
    #     i?86)   ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    #     ;;
    #     x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
    #             ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    #     ;;
    # esac
    ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
    ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    mkdir -v build
    cd       build
    CC="gcc -ffile-prefix-map=/tools=/usr" \
    ../configure --prefix=/usr                          \
                 --disable-werror                       \
                 --enable-kernel=3.2                    \
                 --enable-stack-protector=strong        \
                 --with-headers=/usr/include            \
                 libc_cv_slibdir=/lib
    make
    # case $(uname -m) in
    #   i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
    #   x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
    # esac
    ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib
    make check
    delay
    touch /etc/ld.so.conf
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
    make install
    cp -v ../nscd/nscd.conf /etc/nscd.conf
    mkdir -pv /var/cache/nscd
    mkdir -pv /usr/lib/locale
    localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
    localedef -i de_DE -f ISO-8859-1 de_DE
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
    localedef -i de_DE -f UTF-8 de_DE.UTF-8
    localedef -i el_GR -f ISO-8859-7 el_GR
    localedef -i en_GB -f UTF-8 en_GB.UTF-8
    localedef -i en_HK -f ISO-8859-1 en_HK
    localedef -i en_PH -f ISO-8859-1 en_PH
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
    localedef -i es_MX -f ISO-8859-1 es_MX
    localedef -i fa_IR -f UTF-8 fa_IR
    localedef -i fr_FR -f ISO-8859-1 fr_FR
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
    localedef -i it_IT -f ISO-8859-1 it_IT
    localedef -i it_IT -f UTF-8 it_IT.UTF-8
    localedef -i ja_JP -f EUC-JP ja_JP
    localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
    localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
    localedef -i zh_CN -f GB18030 zh_CN.GB18030
    localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
    make localedata/install-locales
    echo '# Begin /etc/nsswitch.conf
    passwd: files
    group: files
    shadow: files
    hosts: files dns
    networks: files
    protocols: files
    services: files
    ethers: files
    rpc: files
    # End /etc/nsswitch.conf' > /etc/nsswitch.conf
    tar -xf ../../tzdata2019c.tar.gz
    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}
    for tz in etcetera southamerica northamerica europe africa antarctica  \
              asia australasia backward pacificnew systemv; do
        zic -L /dev/null   -d $ZONEINFO       ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        zic -L leapseconds -d $ZONEINFO/right ${tz}
    done
    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO
    ln -sfv /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
    echo '# Begin /etc/ld.so.conf
    /usr/local/lib
    /opt/lib' > /etc/ld.so.conf
    # echo "# Add an include directory" >> /etc/ld.so.conf
    # echo "include /etc/ld.so.conf.d/*.conf" >> /etc/ld.so.conf
    # mkdir -pv /etc/ld.so.conf.d
    ###
    deletesourcesandsave $pkgdir
}

adjust_toolchain_(){
    cd $sourcesdir
    mv -v /tools/bin/{ld,ld-old}
    mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
    mv -v /tools/bin/{ld-new,ld}
    ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
    gcc -dumpspecs | sed -e 's@/tools@@g'                   \
        -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
        -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
        `dirname $(gcc --print-libgcc-file-name)`/specs
    echo 'int main(){}' > dummy.c
    cc dummy.c -v -Wl,--verbose &> dummy.log
    readelf -l a.out | grep ': /lib'
    grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
    grep -B1 '^ /usr/include' dummy.log
    grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
    grep "/lib.*/libc.so.6 " dummy.log
    grep found dummy.log
    delay
    rm -v dummy.c a.out dummy.log
    saveprogress ${FUNCNAME[0]}
}

zlib_(){
    pkgarchive=zlib-1.2.11.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr
    make
    make check
    make install
    mv -v /usr/lib/libz.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
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
    patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/usr install
    cp -v bzip2-shared /bin/bzip2
    cp -av libbz2.so* /lib
    ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
    rm -v /usr/bin/{bunzip2,bzcat,bzip2}
    ln -sv bzip2 /bin/bunzip2
    ln -sv bzip2 /bin/bzcat
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
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/xz-5.2.4
    make
    make check
    make install
    mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
    mv -v /usr/lib/liblzma.so.* /lib
    ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
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
    ./configure --prefix=/usr
    make
    make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

readline_(){
    pkgarchive=readline-8.0.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sed -i '/MV.*old/d' Makefile.in
    sed -i '/{OLDSUFF}/c:' support/shlib-install
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/readline-8.0
    make SHLIB_LIBS="-L/tools/lib -lncursesw"
    make SHLIB_LIBS="-L/tools/lib -lncursesw" install
    mv -v /usr/lib/lib{readline,history}.so.* /lib
    chmod -v u+w /lib/lib{readline,history}.so.*
    ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
    ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.0
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
    ./configure --prefix=/usr
    make
    make check
    make install
    ###
    deletesourcesandsave $pkgdir
}

bc_(){
    pkgarchive=bc-2.5.3.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    PREFIX=/usr CC=gcc CFLAGS="-std=c99" ./configure.sh -G -O3
    make
    make test
    make install
    ###
    deletesourcesandsave $pkgdir
}

binutils_(){
    pkgarchive=binutils-2.34.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    expect -c "spawn ls"
    delay
    sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in
    mkdir -v build
    cd       build
    ../configure --prefix=/usr       \
                 --enable-gold       \
                 --enable-ld=default \
                 --enable-plugins    \
                 --enable-shared     \
                 --disable-werror    \
                 --enable-64-bit-bfd \
                 --with-system-zlib
    make tooldir=/usr
    make -k check
    delay
    make tooldir=/usr install
    ###
    deletesourcesandsave $pkgdir
}

gmp_(){
    pkgarchive=gmp-6.2.0.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr    \
                --enable-cxx     \
                --disable-static \
                --docdir=/usr/share/doc/gmp-6.2.0
    make
    make html
    make check 2>&1 | tee gmp-check-log
    awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
    delay
    make install
    make install-html
    ###
    deletesourcesandsave $pkgdir
}

mpfr_(){
    pkgarchive=mpfr-4.0.2.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr        \
                --disable-static     \
                --enable-thread-safe \
                --docdir=/usr/share/doc/mpfr-4.0.2
    make
    make html
    make check
    delay
    make install
    make install-html
    ###
    deletesourcesandsave $pkgdir
}

mpc_(){
    pkgarchive=mpc-1.1.0.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/mpc-1.1.0
    make
    make html
    make check
    delay
    make install
    make install-html
    ###
    deletesourcesandsave $pkgdir
}

attr_(){
    pkgarchive=attr-2.4.48.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr     \
                --bindir=/bin     \
                --disable-static  \
                --sysconfdir=/etc \
                --docdir=/usr/share/doc/attr-2.4.48
    make
    make check
    delay
    make install
    mv -v /usr/lib/libattr.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
    ###
    deletesourcesandsave $pkgdir
}

acl_(){
    pkgarchive=acl-2.2.53.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr         \
                --bindir=/bin         \
                --disable-static      \
                --libexecdir=/usr/lib \
                --docdir=/usr/share/doc/acl-2.2.53
    make
    make install
    mv -v /usr/lib/libacl.so.* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
    ###
    deletesourcesandsave $pkgdir
}

shadow_(){
    pkgarchive=shadow-4.8.1.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
    sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
           -e 's@/var/spool/mail@/var/mail@' etc/login.defs
    sed -i 's/1000/999/' etc/useradd
    ./configure --sysconfdir=/etc --with-group-name-max-length=32
    make
    make install
    pwconv
    grpconv
    passwd root
    ###
    deletesourcesandsave $pkgdir
}

gcc_(){
    pkgarchive=gcc-9.2.0.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
      ;;
    esac
    sed -e '1161 s|^|//|' \
        -i libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cc
    mkdir -v build
    cd       build
    SED=sed                               \
    ../configure --prefix=/usr            \
                 --enable-languages=c,c++ \
                 --disable-multilib       \
                 --disable-bootstrap      \
                 --with-system-zlib
    make
    ulimit -s 32768
    chown -Rv nobody .
    su nobody -s /bin/bash -c "PATH=$PATH make -k check"
    ../contrib/test_summary
    delay
    make install
    rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/9.2.0/include-fixed/bits/
    chown -v -R root:root \
        /usr/lib/gcc/*linux-gnu/9.2.0/include{,-fixed}
    ln -sv ../usr/bin/cpp /lib
    ln -sv gcc /usr/bin/cc
    install -v -dm755 /usr/lib/bfd-plugins
    ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/9.2.0/liblto_plugin.so \
            /usr/lib/bfd-plugins/
    echo 'int main(){}' > dummy.c
    cc dummy.c -v -Wl,--verbose &> dummy.log
    readelf -l a.out | grep ': /lib'
    grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
    grep -B4 '^ /usr/include' dummy.log
    grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
    grep "/lib.*/libc.so.6 " dummy.log
    grep found dummy.log
    delay
    rm -v dummy.c a.out dummy.log
    mkdir -pv /usr/share/gdb/auto-load/usr/lib
    mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
    ###
    deletesourcesandsave $pkgdir
}

pkg-config_(){
    pkgarchive=pkg-config-0.29.2.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr              \
                --with-internal-glib       \
                --disable-host-tool        \
                --docdir=/usr/share/doc/pkg-config-0.29.2
    make
    make check
    delay
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
    sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --with-shared           \
                --without-debug         \
                --without-normal        \
                --enable-pc-files       \
                --enable-widec
    make
    make install
    mv -v /usr/lib/libncursesw.so.6* /lib
    ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
    for lib in ncurses form panel menu ; do
        rm -vf                    /usr/lib/lib${lib}.so
        echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
    done
    rm -vf                     /usr/lib/libcursesw.so
    echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
    ln -sfv libncurses.so      /usr/lib/libcurses.so
    mkdir -v       /usr/share/doc/ncurses-6.2
    cp -v -R doc/* /usr/share/doc/ncurses-6.2
    ###
    deletesourcesandsave $pkgdir
}

libcap_(){
    pkgarchive=libcap-2.31.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sed -i '/install.*STA...LIBNAME/d' libcap/Makefile
    make lib=lib
    make test
    make lib=lib install
    chmod -v 755 /lib/libcap.so.2.31
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
    sed -i 's/usr/tools/'                 build-aux/help2man
    sed -i 's/testsuite.panic-tests.sh//' Makefile.in
    ./configure --prefix=/usr --bindir=/bin
    make
    make html
    make check
    delay
    make install
    install -d -m755           /usr/share/doc/sed-4.8
    install -m644 doc/sed.html /usr/share/doc/sed-4.8
    ###
    deletesourcesandsave $pkgdir
}

psmisc_(){
    pkgarchive=psmisc-23.2.tar.xz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    ./configure --prefix=/usr
    make
    make install
    mv -v /usr/bin/fuser   /bin
    mv -v /usr/bin/killall /bin
    ###
    deletesourcesandsave $pkgdir
}

iana-etc_(){
    pkgarchive=iana-etc-2.30.tar.bz2
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    make
    make install
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
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.5.2
    make
    make install
    ###
    deletesourcesandsave $pkgdir
}

flex_(){
    pkgarchive=flex-2.6.4.tar.gz
    pkgdir=${pkgarchive%%.tar*}
    cd $sourcesdir
    tar xvf $pkgarchive
    cd ${sourcesdir}/$pkgdir
    ###
    sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
    HELP2MAN=/tools/bin/true \
    ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4
    make
    make check
    delay
    make install
    ln -sv flex /usr/bin/lex
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
    ./configure --prefix=/usr --bindir=/bin
    make
    make check
    delay
    make install
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
    patch -Np1 -i ../bash-5.0-upstream_fixes-1.patch
    ./configure --prefix=/usr                    \
                --docdir=/usr/share/doc/bash-5.0 \
                --without-bash-malloc            \
                --with-installed-readline
    make
    chown -Rv nobody .
    saveprogress ${FUNCNAME[0]}
}

# prompt cores for build
promptcores

# attempt to resume incomplete build
tasks='start; linuxapiheaders_; man_pages_; glibc_; adjust_toolchain_; zlib_; bzip2_; xz_; file_; readline_; m4_; bc_; binutils_; gmp_; mpfr_; mpc_; attr_; acl_; shadow_; gcc_; pkg-config_; ncurses_; libcap_; sed_; psmisc_; iana-etc_; bison_; flex_; grep_; bash_;'
[ -e ~/.lfsresume ] && read lastcomplete < ~/.lfsresume
eval ${tasks##*${lastcomplete:-start};}
