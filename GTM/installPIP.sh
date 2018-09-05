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
su $instance -c "unzip pip.zip > $basedir/log/PIPunzip.log 2>&1"

# Build PIP
mkdir $basedir/pip-build
cd $basedir/pip-build
cmake -D CMAKE_INSTALL_PREFIX=$basedir/pip $basedir/YDBPIP-master && make && make install

# Copy routine to p directory
if [ -d $basedir/p ] ; then
  su $instance -c "cp $basedir/YDBPIP-master/p/*.m $basedir/p"
fi

# Copy ProfileBrowserIDE to proper place
mkdir $basedir/pip/ProfileBrowserIDE
cp $basedir/YDBPIP-master/ProfileBrowserIDE/* $basedir/pip/ProfileBrowserIDE/

# Remove pip build directories
rm -rf $basedir/YDBPIP-master $basedir/pip-build $basedir/pip.zip
cd $basedir/pip

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
perl -pi -e 's#/home/pip/#'$basedir'/#g' $basedir/pip/bin/pipmtm

# Create error paths
mkdir -p /SCA/sca_gtm/alerts/
chmod ugo+rw /SCA/sca_gtm/alerts

# Fix permissions
chown -R $instance:$instance $basedir/pip

# Install Tomcat
curl -fSsLO https://archive.apache.org/dist/tomcat/tomcat-6/v6.0.53/bin/apache-tomcat-6.0.53.tar.gz
tar xzf apache-tomcat-*.tar.gz -C /opt
rm -f apache-tomcat-*.tar.gz
perl -pi -e 's/<Connector port="8080"/<Connector port="8081"/g' /opt/apache-tomcat-*/conf/server.xml

# Install Derby jar
curl -fSsLO http://www-us.apache.org/dist//db/derby/db-derby-10.14.2.0/db-derby-10.14.2.0-lib.zip
unzip db-derby-*.zip
mv db-derby-*-lib/lib/derbyclient.jar /opt/apache-tomcat-*/lib/
mv db-derby-*-lib/lib/derby.jar  /opt/apache-tomcat-*/lib/
mv db-derby-*-lib/lib/derbyrun.jar  /opt/apache-tomcat-*/lib/
mv db-derby-*-lib/lib/derbytools.jar  /opt/apache-tomcat-*/lib/
rm -rf db-derby-*-lib
rm -f db-derby-*-lib.zip

# Extract Derby Database
tar xvzf $basedir/pip/ProfileBrowserIDE/profile_ide_db.tgz -C /opt

# Fix permissions
chown -R $instance:$instance /opt/apache-tomcat-*
chown -R $instance:$instance /opt/profile_ide_db

echo "Done installing PIP"
