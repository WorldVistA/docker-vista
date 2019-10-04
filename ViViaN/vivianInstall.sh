#!/bin/bash

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

yum install -y httpd graphviz java-1.8.0-openjdk-devel php
curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" && \
    python3 get-pip.py
# cp $scriptdir/ViViaN/viv.conf /etc/httpd/conf.d

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
  basedir=/opt/cachesys/$instance
  echo "
//Path to Cache ccontrol
CCONTROL_EXECUTABLE:FILEPATH=/usr/bin/ccontrol

//Cache instance name
VISTA_CACHE_INSTANCE:STRING=cache

//Cache namespace to store VistA
VISTA_CACHE_NAMESPACE:STRING=$namespace" >> $scriptdir/ViViaN/CMakeCache.txt
  connectionArg="-S 1 -CN $namespace"
  sh $basedir/bin/start.sh &
  if [[ ! -f $basedir/mgr/cache.key ]]; then
    serialExport="-sx"
  fi
fi

# Add apache to start.sh
awk -v n=5 -v s='echo "Starting Apache"' 'NR == n {print s} {print}' $basedir/bin/start.sh > $basedir/bin/start.tmp && mv $basedir/bin/start.tmp $basedir/bin/start.sh
awk -v n=6 -v s="/usr/sbin/apachectl" 'NR == n {print s} {print}' $basedir/bin/start.sh > $basedir/bin/start.tmp && mv $basedir/bin/start.tmp $basedir/bin/start.sh
# Fix start.sh permissions
chown cacheusr$instance:cachegrp$instance $basedir/bin/start.sh
chmod +x $basedir/bin/start.sh

mkdir -p /opt/VistA-docs
mkdir -p /opt/viv-out
pushd /opt
echo "Acquiring DBIA/ICR Information from https://foia-vista.osehra.org/VistA_Integration_Agreement/"
curl -fsSL --progress-bar https://foia-vista.osehra.org/VistA_Integration_Agreement/2019_September_10_IA_Listing_Descriptions.TXT -o ICRDescription.txt
echo "Downloading OSEHRA VistA Testing Repository"
curl -fsSL --progress-bar https://github.com/OSEHRA/VistA/archive/master.zip -o VistA-master.zip
unzip -q VistA-master.zip
rm VistA-master.zip
mv VistA-master VistA
echo "Generating VistA-M-like directory"
mkdir -p /opt/VistA-M/Packages
cp /opt/VistA/Packages.csv /opt/VistA-M/

# Install requirements from Testing repository
pip install -r /opt/VistA/requirements.txt

#  Export first so the configuration can find the correct files to query for
echo "Starting VistAMComponentExtractor at:" $(timestamp)
python3 /opt/VistA/Scripts/VistAMComponentExtractor.py $connectionArg -r /opt/VistA-M/ -o /tmp/ -l /tmp/ $serialExport
echo "Ending VistAMComponentExtractor at:" $(timestamp)
# Uncomment to debug VistAMComponentExtractor
# @TODO Make debugging a script option
# echo "Start of Log Dump:"
# cat /tmp/VistAPExpect.log
# echo "End of Log Dump"
find ./VistA-M -type f -print0 | xargs -0 dos2unix > /dev/null 2>&1
find ./VistA-M -type f -name "MPIPSIM*.m" -print0 | xargs -0 rm

if $extractOnly; then
  exit 0
fi
pushd VistA-docs
cp $scriptdir/ViViaN/CMakeCache.txt /opt/VistA-docs
/usr/bin/cmake .
# =====================================================
echo "Starting CTest at:" $(timestamp)
echo "Installing XINDEX patch"
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -R "XINDEX"
echo "Executing XINDEX reports"
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -R "CALLERGRAPH"
echo "Executing data-gathering tasks"
/usr/bin/ctest -V -E "CALLERGRAPH|XINDEX|WebPageGenerator"
echo "Generating ViViaN and DOX HTML"
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -R "WebPageGenerator"
echo "Ending CTest at:" $(timestamp)
# =====================================================
# Clone ViViaN repository
echo "Cloning ViViaN Repository"
curl -fsSL --progress-bar https://github.com/OSEHRA-Sandbox/Product-Management/archive/master.zip -o vivian-master.zip
unzip -q vivian-master.zip
rm vivian-master.zip
mv Product-Management-master /var/www/vivian
ln -s /var/www/vivian/Visual /var/www/html/vivian
ln -s /opt/viv-out/ /var/www/html/vivian/files
pushd /var/www/html/vivian/scripts
python3 setup.py
chown -R apache:apache /var/www/html
rm /etc/httpd/conf.d/welcome.conf