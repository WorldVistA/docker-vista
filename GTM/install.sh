#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2011-2017 The Open Source Electronic Health Record Agent
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#---------------------------------------------------------------------------

# Install GT.M/YottaDB using ydbinstall script
# This utility requires root privliges

# Make sure we are root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Options
# instance = name of instance
# used http://rsalveti.wordpress.com/2007/04/03/bash-parsing-arguments-with-getopts/
# for guidance

usage()
{
    cat << EOF
    usage: $0 options

    This script will automatically install GT.M/YottaDB

    DEFAULTS:
      GT.M Version = V6.3-013
      YottaDB Version = r1.30

    OPTIONS:
      -h    Show this message
      -v    GT.M/YottaDB version to install
      -y    Install YottaDB instead of GT.M
      -s    Skip setting shared memory parameters
      -r    Install from source

EOF
}

while getopts "hrsyv:" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        r)
            source=true
            ;;
        s)
            sharedmem=false
            ;;
        v)
            gtm_ver=$OPTARG
            ;;
        y)
            installYottaDB="true"
    esac
done

# Set defaults for options
# GT.M
if [ -z $gtm_ver ] && [ -z $installYottaDB ]; then
    gtm_ver="V6.3-013"
fi

# YottaDB
if [ $installYottaDB ] && [ -z $gtm_ver ]; then
    gtm_ver="r1.30"
fi

if [ -z $sharedmem ]; then
    sharedmem=true
fi

if [ -z $source ]; then
    source=false
fi

# Determine processor architecture - used to determine if we can use GT.M
#                                    Shared Libraries
# Changed to support ARM chips as well as x64/x86.
arch=$(uname -m | tr -d _)
if [ $arch == "x8664" ]; then
    gtm_arch="x86_64"
else
    gtm_arch=$arch
fi

# Download ydbinstall
if $source; then
    if $installYottaDB; then
        yum install -y \
                    git \
                    gcc \
                    cmake3 \
                    tcsh \
                    {libconfig,gpgme,libicu,libgpg-error,libgcrypt,ncurses,openssl,zlib,elfutils-libelf}-devel \
                    binutils
        git clone https://gitlab.com/YottaDB/DB/YDB.git
        cd YDB
        mkdir build
        cd build
        cmake3 -D CMAKE_INSTALL_PREFIX:PATH=$PWD ../
        make -j `grep -c ^processor /proc/cpuinfo`
        make install
        cd yottadb_r*
        ./ydbinstall --force-install --ucaseonly-utils --utf8 default --installdir /opt/yottadb/"$gtm_ver"_"$gtm_arch"
    else
        echo "Installing GT.M from source isn't supported"
        exit 1
    fi
else
    echo "Downloading ydbinstall"
    curl -s -L https://gitlab.com/YottaDB/DB/YDB/raw/r1.24/sr_unix/ydbinstall.sh?inline=false -o ydbinstall

    isValidFile=`head ydbinstall | grep "Fidelity National Information"`
    if [[ ! $isValidFile ]]; then
        echo "Something went wrong downloading ydbinstall"
        exit $?
    fi

    # Make it executable
    chmod +x ydbinstall

    # Accept most defaults for ydbinstall
    # --ucaseonly-utils - override default to install only uppercase utilities
    #                     this follows VistA convention of uppercase only routines
    # Force install is necessary b/c of a recent change in the YDB installer.
    if [ "$installYottaDB" = "true" ] ; then
        ./ydbinstall --force-install --ucaseonly-utils --utf8 default --installdir /opt/yottadb/"$gtm_ver"_"$gtm_arch" $gtm_ver
    else
        ./ydbinstall --force-install --gtm --ucaseonly-utils --utf8 default --installdir /opt/lsb-gtm/"$gtm_ver"_"$gtm_arch" $gtm_ver
    fi

    # Remove ydbinstall script as it is unnecessary
    rm ./ydbinstall
fi

# Get kernel.shmmax to determine if we can use 32k strings
# ${#...} is to compare lengths of strings before trying to use them as numbers
# Ubuntu 16.04 box seems to have a shared memory of 18446744073692774399!!!
# Bash just starts crying...
if $sharedmem; then
    shmmax=$(sysctl -n kernel.shmmax)
    shmmin=67108864

    if [ ${#shmmax} -ge ${#shmmin} ] || [ $shmmax -ge $shmmin ]; then
        echo "Current shared memory maximum is equal to or greater than 64MB"
        echo "Current shmmax is: " $shmmax
    else
        echo "Current shared memory maximum is less than 64MB"
        echo "Current shmmax is: " $shmmax
        echo "Setting shared memory maximum to 64MB"
        echo "kernel.shmmax = $shmmin" >> /etc/sysctl.conf
        sysctl -w kernel.shmmax=$shmmin
    fi
fi

# Link GT.M shared library where the linker can find it and refresh the cache
if [[ $RHEL || -z $ubuntu ]]; then
    echo "/usr/local/lib" >> /etc/ld.so.conf
fi

rm -f /usr/local/lib/libgtmshr.so
if [ "$installYottaDB" = "true" ] ; then
    ln -s /opt/yottadb/"$gtm_ver"_"$gtm_arch"/libgtmshr.so /usr/local/lib
else
    ln -s /opt/lsb-gtm/"$gtm_ver"_"$gtm_arch"/libgtmshr.so /usr/local/lib
fi
ldconfig
if [ "$installYottaDB" = "true" ] ; then
    echo "Done installing YottaDB"
else
    echo "Done installing GT.M"
fi
