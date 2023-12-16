#!/bin/bash
# NB NB NB: There are tabs in this code. They MUST be kept.
# Needs a parameter: instance name ($1)
instance=$1
ccontrol start CACHE
csession CACHE -U $instance <<END
; Recompile
W "Recompiling Routines",!
D Compile^%R("*.*")
D Compile^%R("%*.*")
; Save pvPostInstall Routine
W "Saving pvPostInstall...",!
d \$SYSTEM.Process.SetZEOF(1)
ZR  ZS pvPostInstall
S F="/opt/vista/Common/pvPostInstall.m"
O F U F ZL  ZS pvPostInstall C F
W "Running pvPostInstall...",!
D ^pvPostInstall
;
; KBANTCLN
S F="/opt/vista/Common/KBANTCLN.m"
ZR  ZS KBANTCLN
O F U F ZL  ZS KBANTCLN C F
W "Cleaning Taskman...",!
S U="^"
D GETENV^%ZOSV S UCI=\$P(Y,U),VOL=\$P(Y,U,2)
D START^KBANTCLN(VOL,UCI,999,"SANDBOX","SANDBOX.OSEHRA.ORG",1)
;
; Save ZSTU in the %SYS - Warning: TABS below are required.
W "Saving ZSTU in %SYS",!
ZN "%SYS"
ZR  ZS ZSTU
ZSTU	;Boot up stuff
	;
	J ZISTCP^XWBTCPM1(9430):"$instance"
	;
	; START TaskMan
	J ^ZTMB:"$instance"
	;
	; START VistALink
	J START^XOBVLL(8001):"$instance"
	QUIT
ZS ZSTU
HALT
;
W "Fixing ISO-8859-1 to ASCII as ISO-8859-1 cannot be exported to JSON in Vivian",!
S ^ONCO(164.33,55,7,5,0)="    (plaque +/- patch)'. The T1a & T1b values are not part of the AJCC algorithm."
S ^ONCO(164.33,55,7,8,0)="    (plaque +/- patch)'. The T2a & T2b values are not part of the AJCC algorithm."
END
ccontrol stop CACHE quietly
