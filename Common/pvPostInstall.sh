#!/bin/bash
# NB NB NB: There are tabs in this code. They MUST be kept.
# Needs a parameter: instance name ($1)
instance=$1
iris start IRIS
iris session IRIS -U $instance <<END
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
END
iris stop IRIS quietly
