/// Apply this via do ##class(%Studio.SourceControl.Interface).SourceControlClassSet("kban.SourceControl.LintHook")
/// Delete the hook via do ##class(%Studio.SourceControl.Interface).SourceControlClassSet("")
/*
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
*/
Class kban.SourceControl.LintHook Extends %Studio.SourceControl.Base
{
  Method OnAfterCompile(InternalName As %String,
                     Object As %RegisteredObject = {$$$NULLOREF}) As %Status
  {
      // Only lint routines (.INT).
      set ext = $zconvert($piece(InternalName, ".", *), "U")
      if (ext '= "INT") quit $$$OK

      set rtn = $piece(InternalName, ".")
      write !, "[XTECROU] linting routine ", rtn, " ..."
      try {
          K ^TMP("KBAN-LINT",$J)
          D CHKROU^XTECROU($NA(^TMP("KBAN-LINT",$J)),rtn)
          F I=0:0 S I=$O(^TMP("KBAN-LINT",$J,I)) Q:'I  W ^(I),!
      } catch ex {
          write !, "[XTECROU] error: ", ex.DisplayString()
      }
      quit $$$OK
  }
}

