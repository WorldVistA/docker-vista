#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2019 Christopher Edwards
# Copyright 2020-2021 Sam Habiel
# Copyright 2021-2022 YottaDB LLC
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
basedir=/home/$instance
# Octo Install now done as part of the YottaDB Install

# Download the VistA Utilities
cd $basedir
if [ ! -d /opt/vista/octo ] ; then
  git clone https://gitlab.com/YottaDB/DBMS/YDBOctoVistA.git
else
  cp -r /opt/vista/YDBOctoVistA $basedir/YDBOctoVistA
fi

# Get the mapping routine and functions routine
su $instance -c "cp $basedir/YDBOctoVistA/_*.m $basedir/r"

# Create Octo Region
cat <<EOF > $basedir/etc/octo.gde
add -segment OCTO -noasyncio -block_size=2048 -allocation=10000 -extension=20000 -global_buffer_count=2000 -file="$basedir/g/octo.dat"
add -region OCTO -record_size=1048576 -key_size=1019 -null_subscripts=always -journal=(before_image,file_name="$basedir/j/octo.mjl") -dynamic_segment=OCTO
add -name %ydbocto* -region=OCTO
show -all
EOF
chown $instance:$instance $basedir/etc/octo.gde

# Create AIM Region
cat <<EOF > $basedir/etc/aim.gde
add -segment AIM -noasyncio -block_size=2048 -allocation=10000 -extension=20000 -global_buffer_count=2000 -file="$basedir/g/aim.dat"
add -region AIM -key_size=1019 -record_size=1048576 -null_subscripts=ALWAYS -journal=(before_image,file_name="$basedir/j/aim.mjl") -dynamic_segment=AIM
add -name %ydbAIM* -r=AIM
show -all
EOF
chown $instance:$instance $basedir/etc/aim.gde

# create the global directory
# have to source the environment first to have YottaDB env vars available
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -run GDE < $basedir/etc/octo.gde > $basedir/log/OctoGDEoutput.log 2>&1"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -run GDE < $basedir/etc/aim.gde > $basedir/log/AIMGDEoutput.log 2>&1"

# Create the database
echo "Creating Octo and AIM databases"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip create -region=OCTO >  $basedir/log/OctoCreateDatabase.log 2>&1"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip create -region=AIM  >> $basedir/log/OctoCreateDatabase.log 2>&1"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip set -journal=\"on\" -file $basedir/g/octo.dat > $basedir/log/OctoAIMEnableJournal.log 2>&1"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mupip set -journal=\"on\" -file $basedir/g/aim.dat >> $basedir/log/OctoAIMEnableJournal.log 2>&1"
echo "Done Creating Octo and AIM databases"

# Add additional Octo items to env script
cat <<EOF >> $basedir/etc/env
export gtmroutines="\$gtmroutines $gtm_dist/plugin/o/_ydbocto.so $gtm_dist/plugin/o/_ydbaim.so"
EOF

echo "Creating admin:admin Octo user"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -run ^%ydboctoAdmin add user admin<< EOF
admin
admin
EOF
> $basedir/log/OctoUserAdd.log 2>&1"
echo "Done Adding Octo functions, metadata, and users"

echo "*                soft    stack           unlimited" >> /etc/security/limits.conf


# Create octo configuration file
cat <<EOF > $basedir/octo.conf
// Specifies the verbosity for logging; options are TRACE, INFO, DEBUG, ERROR, and FATAL
verbosity = "ERROR"

// Settings related to the rocto process
rocto = {
  // Address and port to listen on for connections
  address = "0.0.0.0"
  port = 1338
  // Authentication methods; supported options are "md5"
  authentication_method = "md5"
}
EOF
chown $instance:$instance $basedir/octo.conf

echo "Fix broken Set of Codes DD's introduced by patch ECX*3*178"
echo "See https://gitlab.com/YottaDB/DBMS/YDBOctoVistA/-/issues/26"
$gtm_dist/mumps -dir <<\EOF
S U="^" F I=0:0 S I=$O(^DD(I)) Q:'I  F J=0:0 S J=$O(^DD(I,J)) Q:'J  I $D(^(J,0))#2,$P(^(0),U,2)="S",$P(^(0),U,3)="" S $P(^(0),U,3)="N:NO;Y:YES"
EOF

# Perform mapping
echo "Mapping VistA data to Octo"
su $instance -c "source $basedir/etc/env && \$gtm_dist/mumps -dir << EOF
S DUZ=.5 D Q^DI,MAPALL^%YDBOCTOVISTAM(\"vista-new.sql\")
EOF
> $basedir/log/OctoMapFiles.log 2>&1"
su $instance -c "source $basedir/etc/env && octo -v -f vista-new.sql > $basedir/log/OctoImport.log 2>&1"
echo "Done Mapping VistA data to Octo"

# Load functions SQL
echo "Loading VistA SQL functions"
su $instance -c "source $basedir/etc/env && octo -v -f $basedir/YDBOctoVistA/_YDBOCTOVISTAF.sql > $basedir/log/OctoFunctionsImport.log 2>&1"
echo "Done Loading VistA SQL functions"

echo "Done installing Octo"
