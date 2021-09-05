#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2021 Sam Habiel
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
# Script to install YottaDB GUI

#set -xv

# Ensure presence of required variables
if [ -z $instance ] || [ -z $basedir ]; then
    echo "The required variables are not set (instance, basedir)"
fi

# Options
# instance = name of instance
# used http://rsalveti.wordpress.com/2007/04/03/bash-parsing-arguments-with-getopts/
# for guidance

usage()
{
    cat << EOF
    usage: $0 options

    This script will automatically install YottaDB GUI for YottaDB

    DEFAULTS:
      Node Version = Latest 14.x

    OPTIONS:
      -h    Show this message
      -v    Node Version to install
      -f    Skip setting firewall rules

EOF
}

while getopts ":hfv:" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        f)
            firewall=false
            ;;
        v)
            nodever=$OPTARG
            ;;
    esac
done


# Set defaults for options
if [ -z $nodever ]; then
    nodever="14"
fi

if [[ -z $firewall ]]; then
    firewall=true
fi

echo "nodever $nodever"

# Set the node version
shortnodever=$(echo $nodever | cut -d'.' -f 2)

# set the arch
arch=$(uname -m | tr -d _)

# Download installer in tmp directory
cd $basedir/tmp

# Install node.js using NVM (node version manager)
echo "Downloading NVM installer"
curl -s -k --remote-name -L  https://raw.githubusercontent.com/creationix/nvm/master/install.sh
echo "Done downloading NVM installer"

# Execute it
chmod +x install.sh
su $instance -c "./install.sh"

# Remove it
rm -f ./install.sh

# Install node
su $instance -c "source $basedir/.nvm/nvm.sh && nvm install $nodever && nvm alias default $nodever && nvm use default"

# Get code
su $instance -c "cd $basedir && git clone https://gitlab.com/YottaDB/UI/YDBAdminOpsGUI.git"
cd $basedir/YDBAdminOpsGUI

# Installation 
# Compile Quasar/Vue for serving via Web Server)
su $instance -c "source $basedir/.nvm/nvm.sh && nvm use default && npm install && npm run build"

# Then copy the routines into the p directory
su $instance -c "find . -name '*.m' -type f -exec cp {} $basedir/p/ \;"

# Create startup service
cd $basedir
su $instance -c "cp etc/init.d/ydbgui $basedir/etc"

# Modify init.d scripts to reflect $instance
perl -pi -e 's#/home/foia#'$basedir'#g' $basedir/etc/init.d/ydbgui
ln -s $basedir/etc/init.d/ydbgui /etc/init.d/${instance}vista-ydbgui

if [[ $ubuntu || -z $RHEL ]]; then
    update-rc.d ${instance}vista-ydbgui defaults
fi

if [[ $RHEL || -z $ubuntu ]]; then
    chkconfig --add ${instance}vista-ydbgui
fi

# Add firewall rules
if $firewall; then
  if [[ $RHEL || -z $ubuntu ]]; then
      firewall-cmd --zone=public --add-port=8089/tcp --permanent
      firewall-cmd --reload
  fi
fi

echo "Done installing YottaDB GUI"
