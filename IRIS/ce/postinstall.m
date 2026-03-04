postinstall ; RPMS Post-Install Configuration for IRIS
 ;
 ; This routine performs post-installation configuration for RPMS
 ; running on InterSystems IRIS.
 ;
 WRITE "=== RPMS Post-Install Configuration ===",!
 WRITE "Starting configuration at "_$ZDATETIME($HOROLOG),!
 ;
 ; 1. Initialize FileMan if present
 DO INITFM
 ;
 ; 2. Configure RPMS parameters
 DO CONFIGRPMS
 ;
 ; 3. Set up demo users if applicable
 DO SETUPUSERS
 ;
 ; 4. Configure system parameters
 DO SYSCONFIG
 ;
 WRITE !,"=== Post-Install Configuration Complete ===",!
 QUIT
 ;
INITFM ; Initialize FileMan
 WRITE !,"Checking for FileMan...",!
 ;
 ; Check if FileMan is present
 IF '$DATA(^DD) DO  QUIT
 . WRITE "FileMan not found - skipping initialization",!
 ;
 ; Try to run DT^DICRW to initialize FileMan
 NEW $ETRAP SET $ETRAP="GOTO INITFMERR"
 DO DT^DICRW
 WRITE "FileMan initialized successfully",!
 QUIT
 ;
INITFMERR ; FileMan initialization error handler
 SET $ETRAP=""
 WRITE "Warning: Could not initialize FileMan",!
 QUIT
 ;
CONFIGRPMS ; Configure RPMS parameters
 WRITE !,"Configuring RPMS parameters...",!
 ;
 ; Set up RPMS Site File if it exists
 IF '$DATA(^DIC(9999999.39)) DO  QUIT
 . WRITE "RPMS Site File not found - skipping configuration",!
 ;
 NEW FDA,DIERR
 ;
 ; Configure for UNIX/Linux environment
 SET FDA(9999999.39,"1,",.21)="UNIX"
 ; Set file import/export paths to /tmp/
 SET FDA(9999999.39,"1,",1)="/tmp/"
 SET FDA(9999999.39,"1,",2)="/tmp/"
 ;
 IF $DATA(^DD(9999999.39)) DO
 . DO FILE^DIE("E",$NAME(FDA))
 . IF $DATA(DIERR) DO
 . . WRITE "Warning: Error configuring RPMS Site File",!
 . ELSE  DO
 . . WRITE "RPMS Site File configured successfully",!
 QUIT
 ;
SETUPUSERS ; Set up demo users
 WRITE !,"Checking user configuration...",!
 ;
 ; Check if VA New Person file exists
 IF '$DATA(^VA(200)) DO  QUIT
 . WRITE "New Person file not found - skipping user setup",!
 ;
 ; Update verify code expiration dates for demo users
 NEW I,Z
 FOR I=.9:0 SET I=$ORDER(^VA(200,I)) QUIT:'I  DO
 . SET Z=$GET(^VA(200,I,0))
 . IF $PIECE(Z,"^",3)]"" DO
 . . ; Reset verify code expiration to today
 . . SET $PIECE(^VA(200,I,.1),"^")=$HOROLOG
 ;
 WRITE "User configuration complete",!
 QUIT
 ;
SYSCONFIG ; Configure system parameters
 WRITE !,"Configuring system parameters...",!
 ;
 ; Set default UCI if applicable
 NEW Y
 IF $TEXT(GETENV^%ZOSV)]"" DO
 . DO GETENV^%ZOSV
 . WRITE "System environment: ",$PIECE(Y,"^",1),!
 ;
 ; Configure terminal settings
 ; Set device parameters for proper IRIS/Linux operation
 ;
 WRITE "System configuration complete",!
 QUIT
