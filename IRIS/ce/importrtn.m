ROUTINE importrtn [Type=MAC]
importrtn ; Import RPMS routines from .m files
 ;
 ; Loads all .m files from a directory listing into the current namespace
 ; Uses %Routine to read each file and save as a MAC routine
 ;
 SET file="/tmp/routines.lst"
 OPEN file:("R"):5 ELSE  WRITE "Cannot open routine list",! QUIT
 SET (total,ok,err)=0
 ; TRY/CATCH for EOF — IRIS throws <ENDOFFILE> at end of file
 TRY {
   FOR  USE file READ path DO
   . SET total=total+1
   . IF '(total#500) USE 0 WRITE "  Loaded "_total_" routines...",! USE file
   . DO LOADONE(path,.ok,.err)
 } CATCH e { }
 CLOSE file
 USE 0
 WRITE "Routines loaded: "_ok_" ok, "_err_" errors, "_total_" total",!
 QUIT
 ;
LOADONE(path,ok,err) ; Load a single .m file as a routine
 NEW rtnName,stream,rtn,line,sc
 ; Extract routine name from filename (basename minus .m extension)
 SET rtnName=$PIECE(path,"/",$LENGTH(path,"/"))
 SET rtnName=$PIECE(rtnName,".",1)
 IF rtnName="" SET err=err+1 QUIT
 ;
 TRY {
   ; Read source file via stream
   SET stream=##class(%FileCharacterStream).%New()
   SET stream.Filename=path
   ;
   ; Create/replace routine
   SET rtn=##class(%Routine).%New(rtnName_".MAC")
   WHILE 'stream.AtEnd {
     SET line=stream.ReadLine()
     DO rtn.WriteLine(line)
   }
   SET sc=rtn.Save()
   IF sc SET ok=ok+1
   ELSE  SET err=err+1
 } CATCH e {
   SET err=err+1
 }
 QUIT
