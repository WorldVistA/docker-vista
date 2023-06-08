#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2011-2012,2019 The Open Source Electronic Health Record Alliance
# Copyright 2017 Christopher Edwards
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

# Installs Intersystems Caché in an automated way
# This utility requires root privliges

# Make sure we are root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Options
# used http://rsalveti.wordpress.com/2007/04/03/bash-parsing-arguments-with-getopts/
# for guidance

usage()
{
    cat << EOF
    usage: $0 options

    This script will install Caché and create a VistA instance

    OPTIONS:
      -h    Show this message
      -f    Skip setting firewall rules
      -i    Instance name
      -r    Do RPMS instead of VistA
EOF
}

while getopts ":hfri:" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        f)
            firewall=false
            ;;
        r)
            rpms=true
            ;;
        i)
            instance=$(echo $OPTARG |tr '[:upper:]' '[:lower:]')
            ;;
    esac
done

if [[ -z $instance ]]; then
    usage
    exit 1
fi

if [[ -z $firewall ]]; then
    firewall=true
fi

if [[ -z $rpms ]]; then
    rpms=false
fi

# hack for CentOS
# TODO: Now that moved to Rocky Linux, see if this is needed.
cp /etc/redhat-release /etc/redhat-release.orig
echo "Red Hat Enterprise Linux (Santiago) release 6" > /etc/redhat-release

# Need to know where script was ran from
scriptdir=`dirname $0`

# BaseDir
basedir=/opt/cachesys/$instance

# Create Daemon User accounts
./createDaemonAccount.sh

usermod root -G cachegrp

# unzip the cachekit in a temp directory
cachekit=$(ls -1 /opt/vista/cache-files/cache-*.tar.gz)
echo "Using cache installer: $cachekit"
tempdir=/tmp/cachekit
mkdir $tempdir
chmod og+rx $tempdir
pushd $tempdir
tar xzf $cachekit

# Create environment variables for install
export ISC_PACKAGE_INITIAL_SECURITY="minimal"
export ISC_PACKAGE_MGRUSER=cacheusr
export ISC_PACKAGE_MGRGROUP=cachegrp
export ISC_PACKAGE_INSTANCENAME=CACHE
export ISC_PACKAGE_INSTALLDIR=$basedir
export ISC_PACKAGE_CACHEUSER=cacheusr
export ISC_PACKAGE_CACHEGROUP=cachegrp
export ISC_PACKAGE_STARTCACHE="N"
if $rpms; then
  export ISC_PACKAGE_UNICODE="Y"
fi

# Install Caché
if [ -e cinstall_silent ]; then
    ./cinstall_silent
else
    # the cachekit has a subdirectory before we can find cinstall_silent
    cd $(ls -1)
    ./cinstall_silent
fi

# Bug workaround! --> OSE/SMH - Cache starts, but shouldn't have due to ISC_PACKAGE_STARTCACHE
ccontrol stop CACHE quietly

popd
if [ -e /opt/vista/cache-files/cache.key ]; then
    cp /opt/vista/cache-files/cache.key $basedir/mgr
fi

# Perform subsitutions in cpf file and copy to destination
if $rpms; then
  cp $scriptdir/cache-rpms.cpf $basedir/cache.cpf-new
else
  cp $scriptdir/cache.cpf $basedir/cache.cpf-new
fi
perl -pi -e 's/zzzz/'$instance'/g' $basedir/cache.cpf-new
perl -pi -e 's/ZZZZ/'${instance^^}'/g' $basedir/cache.cpf-new
cp $basedir/cache.cpf-new $basedir/cache.cpf

# Move CACHE.dat
if $rpms; then
  dirname=rpms
else
  dirname=vista
fi
mkdir -p $basedir/$dirname
if [ -e /opt/vista/cache-files/CACHE.DAT ]; then
    echo "Moving CACHE.DAT..."
    mv -v /opt/vista/cache-files/CACHE.DAT $basedir/$dirname/CACHE.DAT
    chown root:cachegrp $basedir/$dirname/CACHE.DAT
    chmod ug+rw $basedir/$dirname/CACHE.DAT
    chmod ug+rw $basedir/$dirname
fi

# Clean up from install
cd $scriptdir
rm -rf $tempdir
mv /etc/redhat-release.orig /etc/redhat-release

# create startup script used by docker
echo "#!/bin/bash"                                      > /bin/start.sh
echo 'trap "ccontrol stop CACHE quietly" SIGTERM'       >> /bin/start.sh
echo 'echo "Starting sshd"'                             >> /bin/start.sh
echo "/usr/sbin/sshd"                                   >> /bin/start.sh
echo 'echo "Starting vista processes"'                  >> /bin/start.sh
echo 'cp '${basedir}'/cache.cpf '${basedir}'/cache.cpf-old' >> /bin/start.sh
echo 'rm '${basedir}'/cache.cpf_*'                      >> /bin/start.sh
echo 'cp '${basedir}'/cache.cpf-new '${basedir}'/cache.cpf' >> /bin/start.sh
echo 'find '${basedir}'/ -iname CACHE.DAT -exec touch {} \;' >>/bin/start.sh
echo "ccontrol start CACHE"                             >> /bin/start.sh
echo '# Create a fifo so that bash can read from it to' >> /bin/start.sh
echo '# catch signals from docker'                      >> /bin/start.sh
echo 'rm -f ~/fifo'                                     >> /bin/start.sh
echo 'mkfifo ~/fifo || exit'                            >> /bin/start.sh
echo 'chmod 400 ~/fifo'                                 >> /bin/start.sh
echo 'read < ~/fifo'                                    >> /bin/start.sh

# Ensure correct permissions for start.sh
chown cacheusr:cachegrp /bin/start.sh
chmod +x /bin/start.sh
