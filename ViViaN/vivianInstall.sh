#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2018-2019 The Open Source Electronic Health Record Alliance
# Copyright 2020-2024 Sam Habiel
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

usage()
{
    cat << EOF
    usage: $0 options

    OPTIONS:
      -h    Show this message
      -s    Script Directory
      -i    Instance name (Namespace/Database for Caché)

EOF
}

while getopts ":h:xi:s:" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        s)
            scriptdir=$OPTARG
            ;;
        i)
            instance=$(echo $OPTARG |tr '[:upper:]' '[:lower:]')
            ;;
        x)
            extractOnly=true
            ;;
    esac
done

timestamp() {
    date +"%Y-%m-%d-%H:%M:%S"
}

if [[ -z $instance ]]; then
    instance=osehra
fi

if [[ -z $scriptdir ]]; then
    scriptdir=/opt/vista
fi
if [[ -z $extractOnly ]]; then
    extractOnly=false
fi

# This is oddly needed... yum install doesn't do it.
mkdir /run/php-fpm

# Install needed packages
yum install -y httpd graphviz java-1.8.0-openjdk-devel php rust cargo openssl-devel php-fpm python3.12 python3.12-pip python3.12-devel freetype-devel

if [[ -f /home/$instance/etc/env ]]; then
  basedir=/home/$instance
  connectionArg="-S 2 -ro $basedir/r/"
  source /home/$instance/etc/env

  # unzip a zip of the single .DAT with a directory of routines
  # and place them in the $basedir
  echo "Using local files found in ./GTM/"
  cd $scriptdir
  #
  unzip -q ./GTM/VistA.zip -d /tmp/gtmout
  pushd /tmp/gtmout/VistA/g/
  # Capture the eventual name
  datFile="$basedir/g/"`ls *.dat`
  #move all .dat files and routine files
  rm -rf $basedir/g
  rm -rf $basedir/r/*.m
  mv /tmp/gtmout/VistA/g $basedir
  mv /tmp/gtmout/VistA/r/* $basedir/r
  # execute GDE to change the default globals to the newly placed file
  # and rundown the file to ensure that it can be accessed
  echo "change -s DEFAULT -f=\"$datFile\"" | mumps -run GDE
  mupip rundown -R DEFAULT
  popd
else
  namespace=$(echo $instance |tr '[:lower:]' '[:upper:]')
  basedir=/opt/irissys/$instance
  echo "
//Cache namespace to store VistA
VISTA_CACHE_NAMESPACE:STRING=$namespace" >> $scriptdir/ViViaN/CMakeCache.txt
  connectionArg="-S 1 -CN $namespace"
  sh $basedir/bin/start.sh &
  if [[ ! -f $basedir/mgr/iris.key ]]; then
    serialExport="-sx"
  fi
fi

# Add apache and php-fpm to start.sh
# php-fpm needed for run PHP from Apache starting in RHEL 8
sed -i '5i echo "Starting Apache"' $basedir/bin/start.sh
sed -i '6i /usr/sbin/php-fpm' $basedir/bin/start.sh
sed -i '7i /usr/sbin/apachectl' $basedir/bin/start.sh
# Fix start.sh permissions
chown root:irisusr $basedir/bin/start.sh
chmod +x $basedir/bin/start.sh

mkdir -p /opt/VistA-docs
mkdir -p /opt/viv-out
pushd /opt

echo "Acquiring DBIA/ICR Information from https://foia-vista.worldvista.org/VistA_Integration_Agreement/"
curl -fsSL --progress-bar https://foia-vista.worldvista.org/VistA_Integration_Agreement/2024_August_13_IA_Listing_Description.txt -o ICRDescription.txt

echo "Downloading OSEHRA VistA Testing Repository"
curl -fsSL --progress-bar https://github.com/WorldVistA/VistA/archive/master.zip -o VistA-master.zip

dir=$(zipinfo -1 VistA-master.zip | head -1 | cut -d/ -f1)
unzip -q VistA-master.zip
rm VistA-master.zip
mv $dir VistA
echo "Generating VistA-M-like directory"
mkdir -p /opt/VistA-M/Packages
cp /opt/VistA/Packages.csv /opt/VistA-M/

# Get MRoutineAnalyzer Repo
git clone https://github.com/WorldVistA/rgivistatools.git /opt/VistA-docs/rgivistatools

# To activate venv if you do a docker exec -it, do this:
# > cd /opt/
# > . vivian-venv/bin/activate

python3.12 -m venv vivian-venv
. vivian-venv/bin/activate

# Install requirements from Testing repository
pip3 install -r /opt/VistA/requirements.txt

# Clone ViViaN repository
echo "Cloning ViViaN Repository"
curl -fsSL --progress-bar https://github.com/WorldVistA/vivian/archive/master.zip -o vivian-master.zip
dir=$(zipinfo -1 vivian-master.zip | head -1 | cut -d/ -f1)
unzip -q vivian-master.zip
rm vivian-master.zip
mv $dir /var/www/html/vivian

# Vivan Step 1: Export Routines and Globals first.
# Uses IRIS. The ZGO routine makes sure not to exceed the job limit (8 jobs)
# To monitor, look at /tmp/VistAPExpect.log and worklist.log
# ZGO takes about 10 minutes
# Python splitting takes a longer time, but is potentially parallelizable
echo "Starting VistAMComponentExtractor at:" $(timestamp)
python3 /opt/VistA/Scripts/VistAMComponentExtractor.py $connectionArg -r /opt/VistA-M/ -o /tmp/ -l /tmp/
echo "Ending VistAMComponentExtractor at:" $(timestamp)
# Uncomment to debug VistAMComponentExtractor
# @TODO Make debugging a script option
#echo "Start of Log Dump:"
# cat /tmp/VistAPExpect.log
#echo "End of Log Dump"
# Exit if the files don't exist... something went wrong
if [ ! -f /tmp/Globals/DD.zwr ] || [ ! -f /tmp/Routines.ro ]; then
  echo "VistAMComponentExtractor failed!"
  exit 1
fi

if $extractOnly; then
  exit 0
fi

pushd VistA-docs
cp $scriptdir/ViViaN/CMakeCache.txt /opt/VistA-docs
/usr/bin/cmake .
mkdir /var/www/html/vivian-data
# =====================================================
echo "Starting CTest at:" $(timestamp)

# Vivian Step 2: Install enhanced XINDEX patch
# Uses IRIS. Now uses DefaultKIDSInstaller.py instead of PatchSequenceApply.py
# Instant
echo "Installing XINDEX patch"
/usr/bin/ctest -V -R "XINDEX"

# Vivian Step 3: Run XINDEX on all the routines and on the package entry + package files (probably from Packages.csv)
# Runs on IRIS
# Single user IRIS allows 8 jobs (and thus -j 8)
#
# Takes 100 minutes (5797.53: TOO LONG!)
# To monitor, run tail -f /opt/VistA-docs/Docs/CallerGraph/Log/*
echo "Executing XINDEX reports"
/usr/bin/ctest -V -j 8 -R "CALLERGRAPH"

# Vivian Step 4:
# - GetFilemanSchema (takes about 80 minutes - 4831.70 sec)
# This runs through the effective list of globals and if there are files there, run XINDEX on them.
# Uses IRIS. Only uses a single job right now to do the work.
# Potentially parallelizable. Even better if it is written in M.
# To monitor, run ls -l /opt/VistA-docs/Docs/Schema | wc -l
# The final count is around 3000 (cat /opt/VistA-docs/globals.lst | wc -l)
#
# Vivian Step 5:
# - MRoutineAnalyzer. Independent. Can be run without the other steps. Fast.
# This runs a Java program that goes through all the routines and gets a list of Fileman calls using DBS API into a a JSON file
# Monitor by looking at the generated file /var/www/html/vivian-data/filemanDBCall.json
#
# Vivian Step 6:
# - ICRParser. Independent. Can be run without the other steps. Fast.
# Converts the ICR file in /opt/ICRDescription.txt to /var/www/html/vivian-data/ICRDescription.JSON.
# Monitor by looking at the generated file.
#
# Vivian Step 7:
# - GenerateNameNumberDisplay. Independent. Can be run without the other steps. Fast.
# Creates /var/www/html/vivian-data/numberspace|namespace/xxx.html files from data in /opt/VistA/Utilities/Dox/Data
# Monitor by looking at the generated file.
#
# Vivian Step 8:
# - GenerateRepoInfo. Independent. Can be run without the other steps. Fast.
# Uses git to get the hash for /opt/VistA-M and stores at /var/www/html/vivian-data/filesInfo.json
#
# Vivian Step 9:
# - GeneratePackageDep. Depends on GetFilemanSchema and MRoutineAnalyzer completing first. Fast.
#
# Vivian Step 10:
# - FileManGlobalDataParser 
# This runs a Python program that creates:
# 1. Each fileman data output for each file as file/entry.html
# 2. Create file.json for the list of entries
# 3. Create Routine-Ref.json of all the Fileman files 
# Really slow, should be parallelized: 4681.99s (80 minutes)
#
# Vivian Step 11:
# - GraphGenerator (614.21s = 10 minutes)
# Generate Graphs for DOX pages. Relies on a lot of the previous steps. Needs to be run alone. Multiprocessor!
# Maybe convert over to each one manually
echo "Executing data-gathering tasks"
/usr/bin/ctest -V -E "CALLERGRAPH|XINDEX|WebPageGenerator"

# Vivian Step 12:
# - WebPageGenerator (about 500 seconds)
# Create the webpages

echo "Generating ViViaN and DOX HTML"
/usr/bin/ctest -V -R "WebPageGenerator"
echo "Ending CTest at:" $(timestamp)
# =====================================================
pushd /var/www/html/vivian/scripts
python3 setup.py -fd /var/www/html/vivian-data -dd /var/www/html/dox
rm /etc/httpd/conf.d/welcome.conf

# Deactivate venv
deactivate
