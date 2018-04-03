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

while getopts ":ha:cbemdgiv:p:sr:wy" option
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

sh /opt/cachesys/${instance}/bin/start.sh &
mkdir -p /opt/VistA-docs
mkdir -p /opt/viv-out
pushd /opt
echo "Downloading OSEHRA VistA"
curl -fsSL --progress-bar https://foia-vista.osehra.org/VistA_Integration_Agreement/2018_January_22_IA_Listing_Descriptions.TXT -o ICRDescription.txt
#change from default to test capitalization changes
curl -fsSL --progress-bar https://github.com/josephsnyder/VistA/archive/fix_capitalizations.zip -o VistA-master.zip
unzip -q VistA-master.zip
rm VistA-master.zip
mv VistA-fix_capitalizations VistA
echo "Downloading OSEHRA VistA-M"
curl -fsSL --progress-bar https://github.com/OSEHRA/VistA-M/archive/master.zip -o VistA-M-master.zip
unzip -q VistA-M-master.zip
rm VistA-M-master.zip
mv VistA-M-master VistA-M

namespace=$(echo $instance |tr '[:lower:]' '[:upper:]')
#  Export first so the configuration can find the correct files to query for
python /opt/VistA/Scripts/VistAMComponentExtractor.py -S 1 -r ./VistA-M -o /tmp/ -l /tmp/ -CN $namespace
# Uncomment to debug VistAMComponentExtractor
# @TODO Make debugging a script option
# echo "Start of Log Dump:"
# cat /tmp/VistAPExpect.log
# echo "End of Log Dump"
find ./VistA-M -type f -print0 | xargs -0 dos2unix > /dev/null 2>&1
pushd VistA-docs
cp $scriptdir/ViViaN/CMakeCache.txt /opt/VistA-docs
/usr/bin/cmake .
# It would be nice to have the CTest command work, commenting it out for now
# TODO: Figure out the FileManGlobalDataParser issue
# =====================================================
echo "Starting CTest at:" $(timestamp)
/usr/bin/ctest -V -j $(grep -c ^processor /proc/cpuinfo)
echo "Ending CTest at:" $(timestamp)
# =====================================================