#!/bin/bash
mkdir /tmp/kids
mkdir /tmp/kids/logs
pushd /tmp/kids

# Download KIDS build for Plan 6 Lexicon
curl -sSOL https://github.com/OSEHRA-Sandbox/VistA-M/releases/download/kcd7/UKO_KCD7_LOAD_0p2.KID

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
  echo "Downloading OSEHRA VistA Tester Repo"
  curl -fsSL --progress-bar https://github.com/OSEHRA/VistA/archive/master.zip -o VistA-master.zip
  unzip -q VistA-master.zip
  rm VistA-master.zip
  mv VistA-master VistA
  vistaDir="/tmp/kids/VistA/Scripts"
fi

# Installs as the DUZ=1 user
python $vistaDir/PatchSequenceApply.py -S $system -p /tmp/kids $instanceName -l /tmp/kids/logs -i -n ALL -d 1
popd
rm -rf /tmp/kids

# Postinstall for OSEHRA VistA Plan 6
# See IMPORTANT notes in the .m file.
cp ./Common/ov6piko.m $basedir/r/
$gtm_dist/mumps -r ov6piko

