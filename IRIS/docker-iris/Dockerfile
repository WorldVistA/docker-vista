#---------------------------------------------------------------------------
# Copyright 2026 Sam Habiel
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
#
# Instructions:
# Get latest FOIA, unzip
# $ wget https://foia-vista.worldvista.org/DBA_VistA_FOIA_System_Files/DBA_VISTA_FOIA_2026/DBA_VISTA_FOIA_20260409.zip
# $ unzip DBA_VISTA_FOIA_20260409.zip
# $ rm DBA_VISTA_FOIA_20260409.zip
#
# Build, run,
# $ docker build -t foia .
# $ rm IRIS.DAT
# Create a file called 'password.txt' containing your password for _SYSTEM user
# $ docker run --name foia -d -p 1972:1972 -p 52773:52773 -v $PWD:/password foia --password-file /password/password.txt
# $ docker exec -it foia bash
# $ iris session IRIS -U VISTA
#
# Management console at http://localhost:52773/csp/sys/%25CSP.Portal.Home.zen

FROM containers.intersystems.com/intersystems/iris-community:latest-em

USER root
RUN mkdir -p /usr/irissys/mgr/VISTA && chown -R 51773:51773 /usr/irissys/mgr/VISTA

USER 51773

ADD --chown=51773:51773 https://github.com/shabiel/VPE/releases/download/v15.2/VPE15P2.RSA /tmp/VPE15P2.RSA
COPY --chown=51773:51773 IRIS.DAT /usr/irissys/mgr/VISTA/IRIS.DAT
COPY --chown=51773:51773 merge.cpf /tmp/
COPY --chown=51773:51773 kban.SourceControl.LintHook.cls /tmp/
ADD --chown=51773:51773 utilities_install.sh /tmp/

RUN iris start IRIS \
 && iris merge IRIS /tmp/merge.cpf \
 && /tmp/utilities_install.sh \
 && iris stop IRIS quietly \
 && rm /tmp/merge.cpf /tmp/VPE15P2.RSA /tmp/utilities_install.sh /tmp/kban.SourceControl.LintHook.cls
