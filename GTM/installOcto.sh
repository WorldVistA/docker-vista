#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2019 Christopher Edwards
# Copyright 2020 Sam Habiel
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

# Install SQL Mapping for VistA using Octo
echo "Begin installing Octo"
basedir=/home/$instance

# Install Octo Prerequisites
yum install epel-release
yum install -y cmake3
yum install -y vim-common bison flex readline-devel libconfig-devel openssl-devel

# Install ydb posix plugin
echo "Installing YDB Posix Plugin"
cd $basedir
git clone https://gitlab.com/YottaDB/Util/YDBposix.git
mkdir YDBposix/build
cd YDBposix/build
cmake3 .. && make && make install

# Download the Octo repository
cd $basedir
if [ ! -d /opt/vista/octo ] ; then
  git clone https://gitlab.com/YottaDB/DBMS/YDBOcto.git
else
  cp -r /opt/vista/octo $basedir/YDBOcto
fi

# Build Octo
export ydb_dist=$gtm_dist
echo $gtm_dist
echo $ydb_dist
mkdir $basedir/YDBOcto/build
cd $basedir/YDBOcto/build
cmake3 .. && make && make install

# Create the octo routines directory
mkdir $basedir/octoroutines
chown -R $instance:$instance $basedir/octoroutines

# Get the mapping routine
cd $basedir/r
su $instance -c "curl -s -L https://gitlab.com/YottaDB/DBMS/ydbvistaocto/raw/master/_YDBOCTOVISTAM.m?inline=false -o _YDBOCTOVISTAM.m"
cd $basedir

# Create Octo database
echo "a -s OCTO -alloc=4000 -exten=5000 -glob=2000 -FILE=$basedir/g/octo.dat" > $basedir/etc/octo.gde
echo "a -r OCTO -RECORD_SIZE=600000 -KEY_SIZE=1019 -NULL_SUBSCRIPTS=ALWAYS -JOURNAL=(BEFORE_IMAGE,FILE_NAME=\"$basedir/j/octo.mjl\") -DYNAMIC_SEGMENT=OCTO" >> $basedir/etc/octo.gde
echo "a -n %ydbocto* -r=OCTO" >> $basedir/etc/octo.gde
echo "sh -a" >> $basedir/etc/octo.gde
chown $instance:$instance $basedir/etc/db.gde

# create the global directory
# have to source the environment first to have YottaDB env vars available
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -run GDE < $basedir/etc/octo.gde > $basedir/log/OctoGDEoutput.log 2>&1"

# Create the database
echo "Creating Octo database"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip create > $basedir/log/OctoCreateDatabase.log 2>&1"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip set -journal=\"enable,on,before,file=$basedir/j/octo.mjl\" -file $basedir/g/octo.dat > $basedir/log/OctoEnableJournal.log 2>&1"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip set -null=existing -file $basedir/g/vehu.dat > $basedir/log/OctoSubscriptsExisting.log 2>&1"
echo "Done Creating Octo database"

# Add additional Octo items to env script
echo "export GTMCI=\$gtm_dist/plugin/ydbocto.ci" >> $basedir/etc/env
echo "export ydb_dist=\$gtm_dist" >> $basedir/etc/env
echo "export gtmroutines=\"$basedir/octoroutines \$gtm_dist/plugin/o/_ydbocto.so \$gtm_dist/plugin/o/_ydbposix.so \$gtmroutines\"" >> $basedir/etc/env
echo "export GTMXC_ydbposix=\$gtm_dist/plugin/ydbposix.xc" >> $basedir/etc/env
# TODO: Remove when my MR to fix this is merged (smh)
echo "export LD_LIBRARY_PATH=\$gtm_dist" >> $basedir/etc/env

# Add custom functions
echo "Adding Octo functions, metadata, and users"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -dir << EOF
s ^%ydboctoocto(\"functions\",\"SQL_FN_REPLACE\")=\"\$\$REPLACE^%YDBOCTOVISTAM\"
EOF
> $basedir/log/OctoAddFunctions.log 2>&1"

echo "Mapping VistA data to Octo"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -run ^%ydboctoAdmin add user admin<< EOF
admin
admin
EOF
> $basedir/log/OctoUserAdd.log 2>&1"
echo "Done Adding Octo functions, metadata, and users"

echo "*                soft    stack           unlimited" >> /etc/security/limits.conf


# Create octo configuration file
echo "// Specifies the verbosity for logging; options are TRACE, INFO, DEBUG, ERROR, and FATAL"          > $basedir/octo.conf
echo 'verbosity = "INFO"'                                                                                >> $basedir/octo.conf
echo "// Location to cache generated M routines which represent queries"                                 >> $basedir/octo.conf
echo 'octo_zroutines = "'$basedir'/octoroutines"'                                                        >> $basedir/octo.conf
echo "// Global directory to use for Octo globals; if not present, we use the ydb_gbldir"                >> $basedir/octo.conf
echo '//octo_global_directory = "'$basedir'/g/'$instance'.gld"'                                          >> $basedir/octo.conf
echo ""                                                                                                  >> $basedir/octo.conf
echo "// Settings related to the octod process"                                                          >> $basedir/octo.conf
echo "rocto = {"                                                                                         >> $basedir/octo.conf
echo "  // Address and port to listen on for connections"                                                >> $basedir/octo.conf
echo '  address = "0.0.0.0"'                                                                             >> $basedir/octo.conf
echo "  port = 1338"                                                                                     >> $basedir/octo.conf
echo '  // Authentication methods; supported options are "md5"'                                          >> $basedir/octo.conf
echo '  authentication_method = "md5"'                                                                   >> $basedir/octo.conf
echo "}"                                                                                                 >> $basedir/octo.conf
echo ""                                                                                                  >> $basedir/octo.conf
echo "// Settings controlling YottaDB; these get set as environment variables during startup"            >> $basedir/octo.conf
echo "// Defined environment variables will take precedence"                                             >> $basedir/octo.conf
chown $instance:$instance $basedir/octo.conf

# Perform mapping
echo "Mapping VistA data to Octo"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -dir << EOF
S DUZ=.5 D Q^DI,MAPALL^%YDBOCTOVISTAM(\"vista-new.sql\")
EOF
> $basedir/log/OctoMapFiles.log 2>&1"
su $instance -c "source $basedir/etc/env && octo -f vista-new.sql > $basedir/log/OctoImport.log 2>&1"
echo "Done Mapping VistA data to Octo"

echo "Done installing Octo"
