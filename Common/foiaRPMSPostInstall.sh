#!/bin/bash
# NB NB NB: There are tabs in this code. They MUST be kept.
# Needs a parameter: instance name ($1)
instance=$1

# Detect whether we have IRIS or Caché
if command -v iris &>/dev/null; then
    IRISCTL="iris"
    IRISSESSION="iris session"
    IRISINSTANCE="IRIS"
elif command -v ccontrol &>/dev/null; then
    IRISCTL="ccontrol"
    IRISSESSION="csession"
    IRISINSTANCE="CACHE"
else
    echo "ERROR: Neither iris nor ccontrol found"
    exit 1
fi

$IRISCTL start $IRISINSTANCE
$IRISSESSION $IRISINSTANCE -U $instance <<END
; Recompile
W "Recompiling Routines",!
D Compile^%R("*.*")
D Compile^%R("%*.*")
d \$SYSTEM.Process.SetZEOF(1)
;
; KBANTCLN
S F="/opt/vista/Common/KBANTCLN.m"
ZR  ZS KBANTCLN
O F U F ZL  ZS KBANTCLN C F
W "Cleaning Taskman...",!
S U="^"
D GETENV^%ZOSV S UCI=\$P(Y,U),VOL=\$P(Y,U,2)
D START^KBANTCLN(VOL,UCI,999,"RPMS SANDBOX","RPMS.SANDBOX.OSEHRA.ORG",1)
; Save ZSTU in the %SYS - Warning: TABS below are required.
W "Saving ZSTU in %SYS",!
ZN "%SYS"
ZR  ZS ZSTU
ZSTU	;Boot up stuff
	; START TaskMan
	J ^ZTMB:"$instance"
	;
	; Start CIA Listener
	J EN^CIANBLIS(9100):"$instance"
	;
	; Start BMX Listner
	J MON^BMXMON(9101):"$instance"
	;
	QUIT
ZS ZSTU
HALT
END
$IRISCTL stop $IRISINSTANCE quietly
