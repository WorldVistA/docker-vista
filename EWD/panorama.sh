#!/usr/bin/env bash
#---------------------------------------------------------------------------
# Copyright 2017 KRM Associates, Inc.
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

# Script to install Panorama

# Ensure presence of required variables
if [[ -z $instance && $gtmver && $gtm_dist && $basedir ]]; then
    echo "The required variables are not set (instance, gtmver, gtm_dist)"
fi

echo "Installing Panorama"

# Overwrite the config to add Panorama routes
cat > $basedir/qewd/qewd.js << EOF
var config = {
  managementPassword: 'keepThisSecret!',
  serverName: '${instance} QEWD Server',
  port: 8080,
  poolSize: 5,
  database: {
    type: 'gtm'
  }
};

var routes = [{
  path: '/ewd-vista-pushdata',
  module: 'ewd-vista-push-handler'
}]

var qewd = require('qewd').master;
qewd.start(config, routes);
EOF

# Install published modules
su - $instance <<'EOF'
source $basedir/.nvm/nvm.sh
cd $basedir/qewd
npm install ewd-vista                    &>> $basedir/log/ewd-vistaInstall.log
npm install ewd-vista-login              &>> $basedir/log/ewd-vistaInstall.log
npm install ewd-vista-bedboard           &>> $basedir/log/ewd-vistaInstall.log
npm install ewd-vista-taskman-monitor    &>> $basedir/log/ewd-vistaInstall.log
npm install ewd-vista-fileman            &>> $basedir/log/ewd-vistaInstall.log
npm install ewd-vista-pharmacy           &>> $basedir/log/ewd-vistaInstall.log
npm install ewd-vista-push-handler       &>> $basedir/log/ewd-vistaInstall.log
npm install ewd-vista-viewer             &>> $basedir/log/ewd-vistaInstall.log
mkdir -p $basedir/qewd/www/ewd-vista
cp -R $basedir/qewd/node_modules/ewd-vista/www/* $basedir/qewd/www/ewd-vista/
EOF
