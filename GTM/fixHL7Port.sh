#!/bin/bash
$gtm_dist/mumps -direct <<-'END'
 S IEN=$O(^HLCS(870,"E","M",0))
 W "Changing HL7 Listner IEN "_IEN_" port to 5001"
 S FDA(870,IEN_",",400.02)=5001
 D FILE^DIE("","FDA")
END
