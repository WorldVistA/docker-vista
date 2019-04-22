ov6piko ; OSE/SMH - OSEHRA Korean VistA Post Install;2019-04-22  9:50 AM
 ;
 ; *** IMPORTANT ***
 ; This .m file expects data produced by the OSEHRA testing framework.
 ; It is not valid to apply this to an empty VistA instance.
 ; /*** IMPORTANT ***
 ;
intro ; fix intro text
 set ^XTV(8989.3,1,"INTRO",2,0)="  *  VistA 에 오신 것을 환영합니다         "
 ;
users ; change user names
 n fda
 ;
 n c s c=","
 n ra s ra=$$FIND1^DIC(200,,"B","ALEXANDER,ROBERT")
 i ra s fda(200,ra_c,.01)="우리,동건"
 set ^XTV(8989.3,1,"INTRO",05,0)="  * 우리 동건 에게 다음 자격 증명을 사용하십시오"
 ;
 n sm s sm=$$FIND1^DIC(200,,"B","SMITH,MARY")
 i sm s fda(200,sm_c,.01)="하늬,미란"
 set ^XTV(8989.3,1,"INTRO",10,0)="  * 하늬 미란 에게 다음 자격 증명을 사용하십시오"
 ;
 n jc s jc=$$FIND1^DIC(200,,"B","CLERK,JOE")
 i jc s fda(200,jc_c,.01)="샘,경모"
 set ^XTV(8989.3,1,"INTRO",15,0)="  * 샘 경모  에게 다음 자격 증명을 사용하십시오"
 ;
 d FILE^DIE(,"fda")
 ;
patients ; change patient name
 n i,t,fda,DIERR f i=1:1 s t=$p($t(ptdata+i),";;",2) q:t=""  d
 . i $d(^DPT(i,0)) s fda(2,i_c,.01)=t
 d FILE^DIE("E","fda")
 i $D(DIERR) W "Error: " D MSG^DIALOG()
 ;
 ;
kspLang ; change Kernel System Language to Korean
 ; NB: This FDA syntax works only in FM22.2; don't try on FM22.0
 S fda(8989.3,"1,","DEFAULT LANGUAGE")="KOREAN"
 D FILE^DIE("E","fda")
 i $D(DIERR) W "Error: " D MSG^DIALOG()
 quit
 ;
ptdata ; data for patient names
 ;;가,민준
 ;;간,서준
 ;;갈,하준
 ;;감,서윤
 ;;강,서연
 ;;견,지우
 ;;경,서현
 ;;계,다은
 ;;고,시우
 ;;곡,현우
 ;;공,예준
 ;;곽,지민
 ;;관,민서
 ;;교,현우
 ;;구,현준
 ;;국,민재
 ;;궁,우진
 ;;궉,민지
 ;;권,슬기
 ;;근,수진
 ;;금,현정
 ;;기,성민
 ;;Samúelsson,Ólafur Jóhann
 ;;Indriðason,Þórarinn
 ;;
eor ;
