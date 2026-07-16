vivianPostInstall ; Vivian VistA Post Install;2018-03-16  11:07 AM
 W "Deleting source code for DSI*",!
 N R,STOP S (R,STOP)="DSI"
 N %
 F  S R=$O(^$ROUTINE(R)) Q:R=""  Q:$E(R,1,3)'=STOP  S %=##class(%Routine).Delete(R,2)
 ;
 W "Deleting source code for VEJD*",!
 N R,STOP S (R,STOP)="VEJD"
 N %
 F  S R=$O(^$ROUTINE(R)) Q:R=""  Q:$E(R,1,3)'=STOP  S %=##class(%Routine).Delete(R,2)
 ;
 W "Deleting source code for VEN*",!
 N R,STOP S (R,STOP)="VEN"
 N %
 F  S R=$O(^$ROUTINE(R)) Q:R=""  Q:$E(R,1,3)'=STOP  S %=##class(%Routine).Delete(R,2)
 ;
 W "Deleting source code for DSS*",!
 N R,STOP S (R,STOP)="DSS"
 N %
 F  S R=$O(^$ROUTINE(R)) Q:R=""  Q:$E(R,1,3)'=STOP  S %=##class(%Routine).Delete(R,2)
 ;
 W "Deleting invalid fields...",!
 F I=0:0 S I=$O(^DD(I)) Q:'I  F J=0:0 S J=$O(^DD(I,J)) Q:'J  K:'$D(^DD(I,J,0)) ^DD(I,J)
 ;
 ; For Vivian
 ; Activate User One by giving him/her an access code: needed for KIDS installer
 W "Activate User One...",!
 S $P(^VA(200,1,0),"^",3)="USER.1"
 ;
 ; For Vivian
 ; Cleaning HL7 messages from VistA, which can contain non-ISO-8859 characters
 W "Clean HL7 messages from VistA...",!
 K ^HLMA,^HL(772)
 S ^HLMA(0)="HL7 MESSAGE ADMINISTRATION^773PI"
 S ^HL(772,0)="HL7 MESSAGE TEXT^772DI"
 ;
 ; Primary HFS Directory
 W "Fixing Primary HFS Directory...",!
 N KBANFDA,KBANERR
 N OS S OS=$$VERSION^%ZOSV(1)
 S KBANFDA(8989.3,1_",",320)=$S(OS["NT":^%SYS("TempDir"),1:"/tmp/")
 D FILE^DIE(,$NA(KBANFDA),$NA(KBANERR))
 I $D(KBANERR) S $EC=",U1," ; if error filing, crash
 ;
 QUIT
