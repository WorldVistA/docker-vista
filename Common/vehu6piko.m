vehu6piko ; OSE/SMH - VEHU6 Korean VistA Post Install;2019-05-07  12:45 PM
 ;
intro ; fix intro text
 set ^XTV(8989.3,1,"INTRO",2,0)="     VistA 에 오신 것을 환영합니다         "
 quit
 ;
kspNoLang ; change Kernel System Language to Korean
 ; NB: This FDA syntax works only in FM22.2; don't try on FM22.0
 S fda(8989.3,"1,","DEFAULT LANGUAGE")="@"
 D FILE^DIE("E","fda")
 i $D(DIERR) W "Error: " D MSG^DIALOG()
 quit
 ;
kspLang ; change Kernel System Language to Korean
 ; NB: This FDA syntax works only in FM22.2; don't try on FM22.0
 S fda(8989.3,"1,","DEFAULT LANGUAGE")="KOREAN"
 D FILE^DIE("E","fda")
 i $D(DIERR) W "Error: " D MSG^DIALOG()
 quit
 ;
