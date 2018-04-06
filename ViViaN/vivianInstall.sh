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

while getopts ":hi:s" option
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

yum install -y httpd graphviz java-1.8.0-openjdk-devel
curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" && \
    python get-pip.py && \
    pip install xlrd reportlab
# cp $scriptdir/ViViaN/viv.conf /etc/httpd/conf.d
basedir=/opt/cachesys/$instance
awk -v n=5 -v s='echo "Starting Apache"' 'NR == n {print s} {print}' $basedir/bin/start.sh > $basedir/bin/start.tmp && mv $basedir/bin/start.tmp $basedir/bin/start.sh
awk -v n=6 -v s="exec /usr/sbin/apachectl -DFOREGROUND" 'NR == n {print s} {print}' $basedir/bin/start.sh > $basedir/bin/start.tmp && mv $basedir/bin/start.tmp $basedir/bin/start.sh

sh $basedir/bin/start.sh &
mkdir -p /opt/VistA-docs
mkdir -p /opt/viv-out
pushd /opt
echo "Downloading OSEHRA VistA"
curl -fsSL --progress-bar https://foia-vista.osehra.org/VistA_Integration_Agreement/2018_January_22_IA_Listing_Descriptions.TXT -o ICRDescription.txt
#change from default to test capitalization changes
curl -fsSL --progress-bar https://github.com/OSEHRA/VistA/archive/master.zip -o VistA-master.zip
unzip -q VistA-master.zip
rm VistA-master.zip
mv VistA-master VistA
echo "Generating VistA-M-like directory"
mkdir -p /opt/VistA-M/Packages
cp /opt/VistA/Packages.csv /opt/VistA-M/

namespace=$(echo $instance |tr '[:lower:]' '[:upper:]')
#  Export first so the configuration can find the correct files to query for
echo "Starting VistAMComponentExtractor at:" $(timestamp)
python /opt/VistA/Scripts/VistAMComponentExtractor.py -S 1 -r /opt/VistA-M/ -o /tmp/ -l /tmp/ -CN $namespace
echo "Ending VistAMComponentExtractor at:" $(timestamp)
# Uncomment to debug VistAMComponentExtractor
# @TODO Make debugging a script option
# echo "Start of Log Dump:"
# cat /tmp/VistAPExpect.log
# echo "End of Log Dump"
find ./VistA-M -type f -print0 | xargs -0 dos2unix > /dev/null 2>&1
find ./VistA-M -type -f -print0 -name "MPIPSIM*.m" | xargs -0 rm
pushd VistA-docs
cp $scriptdir/ViViaN/CMakeCache.txt /opt/VistA-docs
/usr/bin/cmake .
# It would be nice to have the CTest command work, commenting it out for now
# TODO: Figure out the FileManGlobalDataParser issue
# =====================================================
echo "Starting CTest at:" $(timestamp)
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -E "WebPageGenerator"
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo) -R "WebPageGenerator"
echo "Ending CTest at:" $(timestamp)
# =====================================================
# Clone ViViaN repository
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