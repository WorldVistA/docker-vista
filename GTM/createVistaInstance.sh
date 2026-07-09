#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2011-2018 The Open Source Electronic Health Record Agent
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

# Create directories for instance Routines, Objects, Globals, Journals,
# Temp Files
# This utility requires root privliges

# for debugging
#set -x

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

    This script will create a VistA instance for GT.M/YottaDB

    OPTIONS:
      -h    Show this message
      -f    Skip setting firewall rules
      -i    Instance name
      -r    Put RPMS Scripts into XINETD
      -u    Create VistA/RPMS instance with UTF-8 support
      -y    Use YottaDB
EOF
}

while getopts ":hfui:ry" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        f)
            firewall=false
            ;;
        i)
            instance=$(echo $OPTARG |tr '[:upper:]' '[:lower:]')
            ;;
        r)
            rpmsScripts=true
            ;;
        u)
            utf8=true
            ;;
        y)
            installYottaDB=true
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

if [ -z $installYottaDB ]; then
    installYottaDB=false
fi

if [ -z $rpmsScripts ]; then
    rpmsScripts=false
fi

if [ -z $utf8 ]; then
    utf8=false;
fi

echo "Creating $instance..."


# Find GT.M/YottaDB:
# TODO: take GT.M path as the an argument to bypass logic and force GT.M
#       location
# list directory contents (1 per line) | count lines | strip leading and
#                                                      trailing whitespace

if $installYottaDB; then
    checkDir="/opt/yottadb/"
else
    checkDir="/opt/lsb-gtm/"
fi

gtm_dirs=$(ls -1 $checkDir | wc -l | sed 's/^[ \t]*//;s/[ \t]*$//')
if [ $gtm_dirs -gt 1 ]; then
    echo "More than one version of GT.M/YottaDB installed!"
    echo "Can't determine what version of GT.M/YottaDB to use"
    exit 1
fi

# Only one GT.M version found
gtm_dist=$checkDir$(ls -1 $checkDir)
gtmver=$(ls -1 $checkDir)


# TODO: implement argument for basedir
# $basedir is the base directory for the instance
# examples of $basedir are: /home/$instance, /opt/$instance, /var/db/$instance
basedir=/home/$instance

# Create $instance User/Group
# $instance user is a programmer user
# $instance group is for permissions to other users
# $instance group is auto created by adduser script
echo "Running useradd"
useradd -c "$instance instance owner" -m -U $instance -s /bin/bash

# Pre-create empty executable stubs for tied.sh / prog.sh so useradd -s does not
# warn about a missing shell (Rocky 9 shadow-utils is stricter). The real
# contents are written further down in this script and overwrite the stubs.
mkdir -p /home/$instance/bin
touch /home/$instance/bin/tied.sh /home/$instance/bin/prog.sh
chmod +x /home/$instance/bin/tied.sh /home/$instance/bin/prog.sh
chown -R $instance:$instance /home/$instance/bin

useradd -c "Tied user account for $instance" -M -N -g $instance -s /home/$instance/bin/tied.sh -d /home/$instance ${instance}tied
useradd -c "Programmer user account for $instance" -M -N -g $instance -s /home/$instance/bin/prog.sh -d /home/$instance ${instance}prog

# Passwords for tied/prog are set at container start-up by start.sh
# (random by default, overridable via TIED_PASSWORD / PROG_PASSWORD env vars).

# Make instance Directories
su $instance -c "mkdir -p $basedir/{r,r/$gtmver,g,j,etc,etc/socat.d,log,tmp,bin,lib,www,backup}"

# chmod instance directories to be readable by group
su $instance -c "chmod g+rw $basedir/{r,r/$gtmver,g,j,etc,etc/socat.d,log,tmp,bin,lib,www,backup}"

# Copy standard etc and bin items from repo
su $instance -c "cp -R etc $basedir"
su $instance -c "cp -R bin $basedir"

# Modify socat.d scripts to reflect $instance
perl -pi -e 's/foia/'$instance'/g' $basedir/bin/*.sh
perl -pi -e 's/foia/'$instance'/g' $basedir/etc/socat.d/vista-*

# Disable services not needed for the RPMS build
if ! $rpmsScripts; then
    rm -f $basedir/etc/socat.d/vista-bmxnet $basedir/etc/socat.d/vista-cia
fi

# Modify init.d script to reflect $instance
perl -pi -e 's/foia/'$instance'/g' $basedir/etc/init.d/vista

# Create startup service
# /etc/init.d is not present by default on RHEL 9; create it so start.sh
# can invoke the vista init script by path.
mkdir -p /etc/init.d
ln -s $basedir/etc/init.d/vista /etc/init.d/${instance}vista

# Symlink libs
su $instance -c "ln -s $gtm_dist $basedir/lib/gtm"

# Create profile for instance
# Required GT.M variables
echo "export gtm_dist=$basedir/lib/gtm"         > $basedir/etc/env
echo "export gtm_log=$basedir/log"              >> $basedir/etc/env
echo "export gtm_tmp=$basedir/tmp"              >> $basedir/etc/env
echo "export gtm_linktmpdir=$basedir/tmp"       >> $basedir/etc/env
echo "export gtm_prompt=\"${instance^^}>\""     >> $basedir/etc/env
echo "export gtmgbldir=$basedir/g/$instance.gld" >> $basedir/etc/env
echo "export gtm_zinterrupt='I \$\$JOBEXAM^ZU(\$ZPOSITION)'" >> $basedir/etc/env
echo "export gtm_lct_stdnull=1"                 >> $basedir/etc/env
echo "export gtm_lvnullsubs=2"                  >> $basedir/etc/env
echo "export gtm_zquit_anyway=1"                >> $basedir/etc/env
echo "export PATH=\$PATH:\$gtm_dist"            >> $basedir/etc/env
echo "export basedir=$basedir"                  >> $basedir/etc/env
echo "export gtmver=$gtmver"                    >> $basedir/etc/env
echo "export instance=$instance"                >> $basedir/etc/env
echo "export gtm_sysid=$instance"               >> $basedir/etc/env
echo "export gtm_zstep='n oldio s oldio=\$i u 0 zp @\$zpos b  u oldio'">> $basedir/etc/env
echo "export gtm_link=RECURSIVE"                >> $basedir/etc/env
echo "export gtm_statshare=1"                   >> $basedir/etc/env
echo "export ydb_readline=1"                    >> $basedir/etc/env
if $installYottaDB; then
  echo "export mumps_implementation=YottaDB"    >> $basedir/etc/env
else
  echo "export mumps_implementation=GTM"        >> $basedir/etc/env
fi
echo 'if [ -d $gtm_dist/plugin/bin ]; then'     >> $basedir/etc/env
echo " export PATH=\$gtm_dist/plugin/bin:\$PATH" >> $basedir/etc/env
echo "fi"                                       >> $basedir/etc/env

# NB: gtm_side_effects and gtm_boolean intentionally omitted here.
# While I would use them on production; I want to see if we ever have problems
# using them here.

# Ensure correct permissions for env
chown $instance:$instance $basedir/etc/env

# Source envrionment in bash shell
echo "source $basedir/etc/env" >> $basedir/.bashrc

# Setup base gtmroutines
gtmroutines="\$basedir/r/\$gtmver*(\$basedir/r)"

# This block: Set gtmroutines
# Include Posix as that's required by Octo and GUI
if $utf8; then
  echo "export gtmroutines=\"$gtmroutines $basedir/lib/gtm/plugin/o/utf8/_ydbposix.so $basedir/lib/gtm/utf8/libgtmutil.so\"" >> $basedir/etc/env
else
  echo "export gtmroutines=\"$gtmroutines $basedir/lib/gtm/plugin/o/_ydbposix.so $basedir/lib/gtm/libgtmutil.so\"" >> $basedir/etc/env
fi #utf8
echo "export GTMXC_ydbposix=\"$gtm_dist/plugin/ydbposix.xc\"" >> $basedir/etc/env

# This block: Set utf-8 variables
# LC_ALL & LC_LANG get set to C for a lot of time. We need these here.
if $utf8; then
  echo "export LC_ALL=en_US.UTF8"                       >> $basedir/etc/env
  echo "export LC_LANG=en_US.UTF8"                      >> $basedir/etc/env
  echo "export gtm_chset=utf-8"                         >> $basedir/etc/env
  echo "export gtm_icu_version=$(icu-config --version)" >> $basedir/etc/env
fi

# prog.sh - priviliged (programmer) user access
# Allow access to ZSY
echo "#!/bin/bash"                              > $basedir/bin/prog.sh
echo "source $basedir/etc/env"                  >> $basedir/bin/prog.sh
echo "export gtm_etrap='B'"                     >> $basedir/bin/prog.sh
echo "export SHELL=/bin/bash"                   >> $basedir/bin/prog.sh
echo "#These exist for compatibility reasons"   >> $basedir/bin/prog.sh
echo "alias gtm=\"\$gtm_dist/mumps -dir\""      >> $basedir/bin/prog.sh
echo "alias GTM=\"\$gtm_dist/mumps -dir\""      >> $basedir/bin/prog.sh
echo "alias gde=\"\$gtm_dist/mumps -run GDE\""  >> $basedir/bin/prog.sh
echo "alias lke=\"\$gtm_dist/mumps -run LKE\""  >> $basedir/bin/prog.sh
echo "alias dse=\"\$gtm_dist/mumps -run DSE\""  >> $basedir/bin/prog.sh
echo "\$gtm_dist/mumps -dir"                    >> $basedir/bin/prog.sh

# Ensure correct permissions for prog.sh
chown $instance:$instance $basedir/bin/prog.sh
chmod +x $basedir/bin/prog.sh

# tied.sh - unpriviliged user access
# $instance is their shell - no access to ZSY
# need to set users with $basedir/bin/tied.sh as their shell
echo "#!/bin/bash"                              > $basedir/bin/tied.sh
echo "source $basedir/etc/env"                  >> $basedir/bin/tied.sh
echo "export SHELL=/bin/false"                  >> $basedir/bin/tied.sh
echo "export gtm_nocenable=true"                >> $basedir/bin/tied.sh
echo "export gtm_etrap='D ^%ZTER W !!!! HALT'"  >> $basedir/bin/tied.sh
echo "exec \$gtm_dist/mumps -run ^ZU"           >> $basedir/bin/tied.sh

# Ensure correct permissions for tied.sh
chown $instance:$instance $basedir/bin/tied.sh
chmod +x $basedir/bin/tied.sh

# create startup script used by docker
echo "#!/bin/bash"                                           > $basedir/bin/start.sh
echo 'trap "/etc/init.d/'${instance}'vista stop; /etc/init.d/'${instance}'vista-ydbgui stop" SIGTERM'   >> $basedir/bin/start.sh
echo 'echo "Starting VistA TCP listeners (socat)"'          >> $basedir/bin/start.sh
echo "for svc in $basedir/etc/socat.d/*; do"                >> $basedir/bin/start.sh
echo '  [ -x "$svc" ] || continue'                          >> $basedir/bin/start.sh
echo '  "$svc" &'                                           >> $basedir/bin/start.sh
echo 'done'                                                 >> $basedir/bin/start.sh
echo '# Set passwords for tied/prog users (env override or random)' >> $basedir/bin/start.sh
echo 'TIED_PASSWORD=${TIED_PASSWORD:-$(openssl rand -base64 12)}'   >> $basedir/bin/start.sh
echo 'PROG_PASSWORD=${PROG_PASSWORD:-$(openssl rand -base64 12)}'   >> $basedir/bin/start.sh
echo "echo \"${instance}tied:\$TIED_PASSWORD\" | chpasswd"          >> $basedir/bin/start.sh
echo "echo \"${instance}prog:\$PROG_PASSWORD\" | chpasswd"          >> $basedir/bin/start.sh
echo 'echo "==================================================="'  >> $basedir/bin/start.sh
echo 'echo "VistA account passwords for this container:"'          >> $basedir/bin/start.sh
echo "echo \"  ${instance}tied  \$TIED_PASSWORD\""                  >> $basedir/bin/start.sh
echo "echo \"  ${instance}prog  \$PROG_PASSWORD\""                  >> $basedir/bin/start.sh
echo 'echo "==================================================="'  >> $basedir/bin/start.sh
echo 'echo "Starting sshd"'                                 >> $basedir/bin/start.sh
echo "/usr/sbin/sshd"                                       >> $basedir/bin/start.sh
echo 'echo "Starting vista processes"'                      >> $basedir/bin/start.sh
echo "/etc/init.d/${instance}vista start"                   >> $basedir/bin/start.sh
echo "if [ -f /etc/init.d/${instance}vista-ydbgui ] ; then" >> $basedir/bin/start.sh
echo "	/etc/init.d/${instance}vista-ydbgui start"          >> $basedir/bin/start.sh
echo 'fi'                                                   >> $basedir/bin/start.sh
echo "chmod ug+rw $basedir/tmp/*"                           >> $basedir/bin/start.sh
echo '# Create a fifo so that bash can read from it to'     >> $basedir/bin/start.sh
echo '# catch signals from docker'                          >> $basedir/bin/start.sh
echo 'rm -f ~/fifo'                                         >> $basedir/bin/start.sh
echo 'mkfifo ~/fifo || exit'                                >> $basedir/bin/start.sh
echo 'chmod 400 ~/fifo'                                     >> $basedir/bin/start.sh
echo 'read < ~/fifo'                                        >> $basedir/bin/start.sh

# Ensure correct permissions for start.sh
chown $instance:$instance $basedir/bin/start.sh
chmod +x $basedir/bin/start.sh

# Create Global mapping
# Thanks to Sam Habiel, Gus Landis, and others for the inital values
echo "c -s DEFAULT    -ACCESS_METHOD=BG -BLOCK_SIZE=4096 -ALLOCATION=200000 -EXTENSION_COUNT=1024 -GLOBAL_BUFFER_COUNT=4096 -LOCK_SPACE=400 -FILE=$basedir/g/$instance.dat" > $basedir/etc/db.gde
echo "a -s TEMP       -ACCESS_METHOD=MM -BLOCK_SIZE=4096 -ALLOCATION=10000 -EXTENSION_COUNT=1024 -GLOBAL_BUFFER_COUNT=4096 -LOCK_SPACE=400 -FILE=$basedir/g/temp.dat" >> $basedir/etc/db.gde
echo "c -r DEFAULT    -RECORD_SIZE=16368 -KEY_SIZE=1019 -JOURNAL=(BEFORE_IMAGE,FILE_NAME=\"$basedir/j/$instance.mjl\") -DYNAMIC_SEGMENT=DEFAULT" >> $basedir/etc/db.gde
echo "a -r TEMP       -RECORD_SIZE=16368 -KEY_SIZE=1019 -NOJOURNAL -DYNAMIC_SEGMENT=TEMP"   >> $basedir/etc/db.gde
# Sam sez: This list follows what the VA does for their scripts
for global in TMP TEMP UTILITY XTMP XUTL HLTMP BMXTMP VPRHTTP KMPTMP DISV DOSV SPOOL 'CacheTemp*'; do
  echo "a -n $global -r=TEMP"                  >> $basedir/etc/db.gde
done
# Sam sez: This list was given to me by Floyd Dennis on Dec 12 2017 from the CSMT branch
if $rpmsScripts; then
  for global in ABMDTMP ACPTEMP AGSSTEMP AGSSTMP1 AGSTEMP AGTMP APCHTMP ATXTMP AUMDDTMP AUMDOTMP AUTTEMP BARTMP BDMTMP BDWBLOG BDWTMP BGOTEMP BGOTMP BGPELLDBA BPATEMP BPCTMP BSDZTMP BGPTMP BIPDUE BITEMP BITMP BQIPAT BQIFAC BQIPAT BQIPROV BTPWPQ BTPWQ BUSAD; do
    echo "a -n $global -r=TEMP"                 >> $basedir/etc/db.gde
  done
fi
echo "sh -a"                                    >> $basedir/etc/db.gde

# Ensure correct permissions for db.gde
chown $instance:$instance $basedir/etc/db.gde

# create the global directory
# have to source the environment first to have GTM env vars available
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -run GDE < $basedir/etc/db.gde > $basedir/log/GDEoutput.log 2>&1"

# Create the database
echo "Creating databases"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip create > $basedir/log/createDatabase.log 2>&1"
echo "Done Creating databases"

# Set permissions
chown -R $instance:$instance $basedir
chmod -R g+rw $basedir

# Add firewall rules
if $firewall; then
    if [[ $RHEL || -z $ubuntu ]]; then
        firewall-cmd --zone=public --add-port=9430/tcp --permanent # RPC Broker
        firewall-cmd --zone=public --add-port=8001/tcp --permanent # VistALink
        firewall-cmd --reload
    fi
fi

if ! $rpmsScripts; then
  echo "VistA instance $instance created!"
else
  echo "RPMS instance $instance created!"
fi
