#!/bin/bash
# Set up arguments for PatchSequenceApply script based upon system
system=1
instanceName='-cn $instance'
if ($installgtm || $installYottaDB); then
  system=2
  instanceName=''
fi

# Assume that '-s' was not supplied to Docker build
vistaDir="$basedir/Dashboard/VistA/Scripts"

# But check to be sure and download VistA if necessary
if [ ! -d $vistaDir ]; then
  mkdir /tmp/atf
  pushd /tmp/atf
  echo "Downloading OSEHRA VistA Tester Repo"
  curl -fsSL --progress-bar https://github.com/OSEHRA/VistA/archive/master.zip -o VistA-master.zip
  unzip -q VistA-master.zip
  rm VistA-master.zip
  mv VistA-master VistA
  vistaDir="/tmp/atf/VistA/Scripts"
  popd
fi

cp ./Common/vehu6piko.m $basedir/r/
$gtm_dist/mumps -r intro^vehu6piko           # Add Korean Intro Text
$gtm_dist/mumps -r kspNoLang^vehu6piko       # Remove Korean Lang from Kernel as it changes menus and confuses the OSEHRA Patcher

# Download KIDS build for Plan 6 Lexicon and install as DUZ=1 user
mkdir /tmp/kids
mkdir /tmp/kids/logs
pushd /tmp/kids
curl -sSOL https://github.com/OSEHRA-Sandbox/VistA-M/releases/download/kcd7/UKO_KCD7_LOAD_0P3.KID
python $vistaDir/PatchSequenceApply.py -S $system -p /tmp/kids $instanceName -l /tmp/kids/logs -i -n ALL -d 1
popd

$gtm_dist/mumps -r kspLang^vehu6piko       # Add it back

rm -rf /tmp/kids
rm -rf /tmp/atf

# Free up space in the database
echo "Freeing up space in the database"
$gtm_dist/mupip reorg -truncate -region DEFAULT
$gtm_dist/mupip set -journal="on,before" -region DEFAULT
find $basedir/j/ -name "*.mjl_*" -print -delete
