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
#!/bin/bash
set -xve

# Install VPE from 15.2 RSA file
iris session IRIS -U VISTA %RI<<END
/tmp/VPE15P2.RSA

Y
0
A
Y
Y
Y
END

# Load Linter Hook so that VSCode saves will get linted like Eclipse's M-Tools
iris session IRIS -U VISTA<<'END'
do $system.OBJ.Load("/tmp/kban.SourceControl.LintHook.cls","ck")
do ##class(%Studio.SourceControl.Interface).SourceControlClassSet("kban.SourceControl.LintHook")
HALT
END
