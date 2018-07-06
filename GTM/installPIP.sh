#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2018 Christopher Edwards
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

# Install SQL Mapping for VistA using PIP

echo "Begin installing PIP"
basedir=/home/$instance

# Download the PIP repository
cd $basedir
su $instance -c "curl -s -L https://github.com/YottaDB/PIP/archive/master.zip -o pip.zip"
su $instance -c "unzip pip.zip > $basedir/log/PIPunzip.log 2>&1 && mv PIP-master pip"

# Build PIP

# Build Message Transfer Manager
echo "Building Message Transfer Manager..."
cd $basedir/pip/mtm_*
make > $basedir/log/PIPMTMCompile.log 2>&1

# Build External Call Utility
echo "Building External Call Utility..."
cd $basedir/pip/extcall_*/shlib
make > $basedir/log/PIPshlibCompile.log 2>&1
cd ../alerts
make > $basedir/log/PIPalertsCompile.log 2>&1
cd ../src
make > $basedir/log/PIPextcallCompile.log 2>&1
make -f version.mk > $basedir/log/PIPextcallVersionCompile.log 2>&1

# Build SQL Library
echo "Building SQL Library..."
cd $basedir/pip/libsql_*/src
make LINUX > $basedir/log/PIPlibSQLCompile.log 2>&1
make version > $basedir/log/PIPlibSQLVersionCompile.log 2>&1

# Compile M interrupt
echo "Building M Interrupt..."
cd $basedir/pip/util
make -f mintrpt.mk > $basedir/log/PIPmintrptCompile.log 2>&1

# Create PIP database
echo "a -s PIP      -alloc=4000 -exten=5000 -glob=2000 -FILE=$basedir/g/pip.dat" > $basedir/etc/pip.gde
echo "a -r PIP      -RECORD_SIZE=4080 -KEY_SIZE=255 -JOURNAL=(BEFORE_IMAGE,FILE_NAME=\"$basedir/j/pip.mjl\") -DYNAMIC_SEGMENT=PIP" >> $basedir/etc/pip.gde
echo "a -n %ZDDP    -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n CTBL     -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n CUVAR    -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n DBCTL    -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n DBINDX   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n DBSUCLS  -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n DBSUSER  -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n DBTBL    -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n OBJECT   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n PROCID   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n SCATBL   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n SCAU     -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n SQL      -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n STBL     -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n SVCTRL   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n SYSMAP   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n SYSMAPX  -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n TBXBUILD -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n TBXFIX   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n TBXINST  -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n TBXLOAD  -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n TBXLOG   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n TBXLOGX  -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n TBXREJ   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n UTBL     -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n XDBREF   -r=PIP"    >> $basedir/etc/pip.gde
echo "a -n dbtbl    -r=PIP"    >> $basedir/etc/pip.gde
echo "sh -a"                   >> $basedir/etc/pip.gde

# Ensure correct permissions for pip.gde
chown $instance:$instance $basedir/etc/db.gde

# create the global directory
# have to source the environment first to have GTM env vars available
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -run GDE < $basedir/etc/pip.gde > $basedir/log/PIPGDEoutput.log 2>&1"

# Create the database
echo "Creating PIP database"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip create > $basedir/log/PIPCreateDatabase.log 2>&1"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip set -journal=\"enable,on,before,file=$basedir/j/pip.mjl\" -file $basedir/g/pip.dat"
echo "Done Creating PIP database"

# Import PIP Globals
perl -pi -e 's/GT.M MUPIP EXTRACT UTF-8/GT.M MUPIP EXTRACT/g' $basedir/pip/gbls/globals.zwr
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip load \$basedir/pip/gbls/globals.zwr >> $basedir/log/PIPLoadGlobals.log 2>&1"

# Modify *.xc files to reflect correct path
perl -pi -e 's#/home/pip/#'$basedir'/#g' $basedir/pip/extcall_V1.2/*.xc
perl -pi -e 's#/home/pip/#'$basedir'/#g' $basedir/pip/mtm_V2.4.5/*.xc

# Modify gtmenv to reflect correct paths
perl -pi -e 's#gtm_dist=/opt/yottadb/current#gtm_dist=\$basedir/lib/gtm#g' $basedir/pip/gtmenv
perl -pi -e 's#gtmgbldir=\$\{SCAU_GBLS\}/pip.gld#gtmgbldir=\$basedir/g/\$instance.gld\nunset gtm_lvnullsubs\n#g' $basedir/pip/gtmenv
perl -pi -e 's#rtn_list="\$\{SCAU_PRTNS\} \$\{SCAU_ZRTNS\} \$\{SCAU_SRTNS\}/obj\(\$\{SCAU_SRTNS\}\) \$\{SCAU_MRTNS\}/obj\(\$\{SCAU_MRTNS\}\) \$\{SCAU_CRTNS\}/obj\(\$\{SCAU_CRTNS\}\) \$\{SCA_GTMO\}\(\$\{SCA_RTNS\}\) \$\{gtm_dist\}/utf8/libyottadbutil.so"#rtn_list="\$basedir/p/\$gtmver\(\$basedir/p\) \$basedir/s/\$gtmver\(\$basedir/s\) \$basedir/r/\$gtmver\(\$basedir/r\) \$\{SCAU_PRTNS\} \$\{SCAU_ZRTNS\} \$\{SCAU_SRTNS\}/obj\(\$\{SCAU_SRTNS\}\) \$\{SCAU_MRTNS\}/obj\(\$\{SCAU_MRTNS\}\) \$\{SCAU_CRTNS\}/obj\(\$\{SCAU_CRTNS\}\) \$\{SCA_GTMO\}\(\$\{SCA_RTNS\}\) \$\{gtm_dist\}/libgtmutil.so"#g' $basedir/pip/gtmenv
#unset gtm_lvnullsubs

# Modify gtmenv1 to run in M mode
perl -pi -e 's/export gtm_chset=UTF-8/#export gtm_chset=UTF-8/g' $basedir/pip/gtmenv1
perl -pi -e 's/export LC_CTYPE=en_US.UTF-8/#export LC_CTYPE=en_US.UTF-8/g' $basedir/pip/gtmenv1
perl -pi -e 's/#export gtm_chset=M/export gtm_chset=M/g' $basedir/pip/gtmenv1

# Modify pipstart to reflect correct path
perl -pi -e 's#gbls/mumps.mjl#\$basedir/j/pip.mjl#g' $basedir/pip/pipstart
perl -pi -e 's#gbls/mumps.dat#\$basedir/g/pip.dat#g' $basedir/pip/pipstart
perl -pi -e 's#find gbls -iname mumps.mjl#find \$basedir/j -iname pip.mjl#g' $basedir/pip/pipstart

# Modify pipstop to reflect correct path
perl -pi -e 's#gbls/mumps.mjl#\$basedir/j/pip.mjl#g' $basedir/pip/pipstop
perl -pi -e 's#gbls/mumps.dat#\$basedir/g/pip.dat#g' $basedir/pip/pipstop

# Modify PIPMTM to reflect correct path
perl -pi -e 's#/home/pip/#'$basedir'/#g' $basedir/pip/mtm/PIPMTM

# Create error paths
mkdir -p /SCA/sca_gtm/alerts/
chmod ugo+rw /SCA/sca_gtm/alerts


echo "Done installing PIP"
