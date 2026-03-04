ROUTINE importgbl [Type=MAC]
importgbl ; Import RPMS globals from .zwr files
 ;
 ; Loads all .zwr files from a directory listing into the current namespace
 ; ZWR format: each line is a SET command like ^GLOBAL(sub)=value
 ;
 SET file="/tmp/globals.lst"
 OPEN file:("R"):5 ELSE  WRITE "Cannot open global list",! QUIT
 SET (total,ok,err)=0
 ; TRY/CATCH for EOF — IRIS throws <ENDOFFILE> at end of file
 TRY {
   FOR  USE file READ path DO
   . SET total=total+1
   . IF '(total#100) USE 0 WRITE "  Loaded "_total_" globals...",! USE file
   . DO LOADONE(path,.ok,.err)
 } CATCH e { }
 CLOSE file
 USE 0
 WRITE "Globals loaded: "_ok_" ok, "_err_" errors, "_total_" total",!
 QUIT
 ;
LOADONE(path,ok,err) ; Load a single .zwr file
 NEW line,hdr1,hdr2
 TRY {
   OPEN path:("R"):5 ELSE  SET err=err+1 QUIT
   USE path
   ; Read and skip the two header lines (export header + "ZWR")
   READ hdr1
   READ hdr2
   ; Read and execute each SET line — catch EOF
   TRY {
     FOR  READ line DO
     . IF line'="" SET @line
   } CATCH e2 { }
   CLOSE path
   SET ok=ok+1
 } CATCH e {
   SET err=err+1
   CLOSE path
 }
 QUIT
