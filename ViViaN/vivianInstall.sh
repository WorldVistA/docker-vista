#!/bin/bash

usage()
{
    cat << EOF
    usage: $0 options

    OPTIONS:
      -h    Show this message
      -s    Script Directory
      -i    Instance name (Namespace/Database for Caché)
      -y    Building a non-Cache instance

EOF
}

while getopts ":hi:s:y:" option
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
        y)
            nonCache=$OPTARG
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

if [[ -z $nonCache ]]; then
    nonCache=false
fi

yum install -y httpd graphviz java-1.8.0-openjdk-devel php
curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" && \
    python get-pip.py && \
    pip install xlrd reportlab
# cp $scriptdir/ViViaN/viv.conf /etc/httpd/conf.d

if ! $nonCache; then
  basedir=/opt/cachesys/$instance

  # Fix start.sh permissions
  chown cacheusr$instance:cachegrp$instance $basedir/bin/start.sh
  chmod +x $basedir/bin/start.sh

  sh $basedir/bin/start.sh &
else
  basedir=/home/$instance
fi

# Add apache to start.sh
awk -v n=5 -v s='echo "Starting Apache"' 'NR == n {print s} {print}' $basedir/bin/start.sh > $basedir/bin/start.tmp && mv $basedir/bin/start.tmp $basedir/bin/start.sh
awk -v n=6 -v s="/usr/sbin/apachectl" 'NR == n {print s} {print}' $basedir/bin/start.sh > $basedir/bin/start.tmp && mv $basedir/bin/start.tmp $basedir/bin/start.sh

mkdir -p /opt/VistA-docs
mkdir -p /opt/viv-out
pushd /opt
echo "Acquiring DBIA/ICR Information from https://foia-vista.osehra.org/VistA_Integration_Agreement/"
curl -fsSL --progress-bar https://foia-vista.osehra.org/VistA_Integration_Agreement/2018_January_22_IA_Listing_Descriptions.TXT -o ICRDescription.txt
echo "Downloading OSEHRA VistA Testing Repository"
curl -fsSL --progress-bar https://github.com/josephsnyder/VistA/archive/fix_menus_dir_creation.zip -o VistA-master.zip
unzip -q VistA-master.zip
rm VistA-master.zip
mv VistA-fix_menus_dir_creation VistA
echo "Generating VistA-M-like directory"
mkdir -p /opt/VistA-M/Packages
cp /opt/VistA/Packages.csv /opt/VistA-M/

if $nonCache; then
  connectionArg="-S 2 -ro $basedir/r/"
  source /home/$instance/etc/env
else
  echo "
  //Path to Cache ccontrol
CCONTROL_EXECUTABLE:FILEPATH=/usr/bin/ccontrol

//Cache instance name
VISTA_CACHE_INSTANCE:STRING=cache

//Cache namespace to store VistA
VISTA_CACHE_NAMESPACE:STRING=OSEHRA" >> $scriptdir/ViViaN/CMakeCache.txt
  connectionArg="-S 1 -CN $namespace"
fi

echo $connectionArg
namespace=$(echo $instance |tr '[:lower:]' '[:upper:]')
#  Export first so the configuration can find the correct files to query for
echo "Starting VistAMComponentExtractor at:" $(timestamp)
python /opt/VistA/Scripts/VistAMComponentExtractor.py $connectionArg -r /opt/VistA-M/ -o /tmp/ -l /tmp/
echo "Ending VistAMComponentExtractor at:" $(timestamp)
# Uncomment to debug VistAMComponentExtractor
# @TODO Make debugging a script option
# echo "Start of Log Dump:"
# cat /tmp/VistAPExpect.log
# echo "End of Log Dump"
find ./VistA-M -type f -print0 | xargs -0 dos2unix > /dev/null 2>&1
find ./VistA-M -type f -name "MPIPSIM*.m" -print0 | xargs -0 rm
pushd VistA-docs
cp $scriptdir/ViViaN/CMakeCache.txt /opt/VistA-docs
/usr/bin/cmake .
# =====================================================
echo "Starting CTest at:" $(timestamp)
echo "Installing XINDEX patch"
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -R "XINDEX"
echo "Executing data-gathering tasks"
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -E "WebPageGenerator|FileManGlobalDataParser|XINDEX"
echo "Parsing VistA Globals"
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -R "FileManGlobalDataParser"
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
python setup.py
chown -R apache:apache /var/www/html
rm /etc/httpd/conf.d/welcome.conf