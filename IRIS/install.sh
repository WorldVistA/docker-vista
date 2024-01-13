#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2011-2012,2019 The Open Source Electronic Health Record Alliance
# Copyright 2017 Christopher Edwards
# Copyright 2019-2024 Sam Habiel
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
set -e

# Installs Intersystems IRIS in an automated way
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

    This script will install IRIS and create a VistA instance

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

# Install Apache and ip command
yum install -y httpd iproute

# Hack for Rocky Linux - Pretend to be RHEL, we undo that below
cp /etc/os-release{,.orig}
sed -i 's/ID="rocky"/ID="rhel"/g' /etc/os-release

# Need to know where script was ran from
scriptdir=`dirname $0`

# BaseDir
basedir=/opt/irissys/$instance

# unzip the iriskit in a temp directory
iriskit=$(ls -1 /opt/vista/iris-files/IRIS*.tar.gz)
echo "Using iris installer: $iriskit"
tempdir=/tmp/iriskit
mkdir $tempdir
chmod og+rx $tempdir
pushd $tempdir
tar xzf $iriskit

# Create environment variables for install
export ISC_PACKAGE_INITIAL_SECURITY="minimal"
export ISC_PACKAGE_INSTANCENAME=IRIS
export ISC_PACKAGE_INSTALLDIR=$basedir
export ISC_PACKAGE_STARTIRIS="N"
export ISC_PACKAGE_UNICODE="N"
if $rpms; then
  export ISC_PACKAGE_UNICODE="Y"
fi

# Install IRIS
if [ -e irisinstall_silent ]; then
    ./irisinstall_silent
else
    # the iriskit has a subdirectory before we can find irisinstall_silent
    cd $(ls -1)
    ./irisinstall_silent
fi

popd
if [ -e /opt/vista/iris-files/iris.key ]; then
    cp /opt/vista/iris-files/iris.key $basedir/mgr
fi

# Perform subsitutions in cpf file and copy to destination
if $rpms; then
  cp $scriptdir/iris-rpms.cpf $basedir/iris.cpf-new
else
  cp $scriptdir/iris.cpf $basedir/iris.cpf-new
fi
perl -pi -e 's/zzzz/'$instance'/g' $basedir/iris.cpf-new
perl -pi -e 's/ZZZZ/'${instance^^}'/g' $basedir/iris.cpf-new
cp $basedir/iris.cpf-new $basedir/iris.cpf

# Move IRIS.dat
if $rpms; then
  dirname=rpms
else
  dirname=vista
fi
mkdir -p $basedir/$dirname
if [ -e /opt/vista/iris-files/IRIS.DAT ]; then
    echo "Moving IRIS.DAT..."
    mv -v /opt/vista/iris-files/IRIS.DAT $basedir/$dirname/IRIS.DAT
    chown root:irisusr $basedir/$dirname/IRIS.DAT
    chmod ug+rw $basedir/$dirname/IRIS.DAT
    chmod ug+rw $basedir/$dirname
fi

# Clean up from install
cd $scriptdir
rm -rf $tempdir

# Undo Rocky Linux pretending to be RHEL
mv /etc/os-release{.orig,}

# create startup script used by docker
echo "#!/bin/bash"                                           > $basedir/bin/start.sh
echo 'trap "iris stop IRIS quietly" SIGTERM'                 >> $basedir/bin/start.sh
echo 'echo "Starting sshd"'                                  >> $basedir/bin/start.sh
echo "/usr/sbin/sshd"                                        >> $basedir/bin/start.sh
echo 'echo "Starting vista processes"'                       >> $basedir/bin/start.sh
echo 'cp '${basedir}'/iris.cpf '${basedir}'/iris.cpf-old'    >> $basedir/bin/start.sh
echo 'rm '${basedir}'/iris.cpf_*'                            >> $basedir/bin/start.sh
echo 'cp '${basedir}'/iris.cpf-new '${basedir}'/iris.cpf'    >> $basedir/bin/start.sh
echo "iris start IRIS"                                       >> $basedir/bin/start.sh
echo '# Create a fifo so that bash can read from it to'      >> $basedir/bin/start.sh
echo '# catch signals from docker'                           >> $basedir/bin/start.sh
echo 'rm -f ~/fifo'                                          >> $basedir/bin/start.sh
echo 'mkfifo ~/fifo || exit'                                 >> $basedir/bin/start.sh
echo 'chmod 400 ~/fifo'                                      >> $basedir/bin/start.sh
echo 'read < ~/fifo'                                         >> $basedir/bin/start.sh

# Ensure correct permissions for start.sh
chown root:irisusr $basedir/bin/start.sh
chmod +x $basedir/bin/start.sh
