wvDemopi ; OSE/SMH - WV Demo Instance Post Install ; 10/20/18 9:37pm
 ;
 S U="^"
 S DUZ=1 D DUZ^XUP(DUZ)
 ;
inact ; Inactivate all users and delete all old ac/vc
 W "Inactivting all users...",!
 N I F I=0:0 S I=$O(^VA(200,I)) Q:'I  D
 . S $P(^VA(200,I,0),U,3)=""  ; AC
 . S $P(^VA(200,I,.1),U,2)="" ; VC
 . S $P(^VA(200,I,.1),U,1)="" ; VC last changed
 . K ^VA(200,I,"VOLD") ; old VC for each user
 K ^VA(200,"AOLD") ; Old AC for users
 K ^VA(200,"A")    ; Current AC for users
 ;
prov ; Create Providers
 D MES^XPDUTL("Creating Users...")
 D MES^XPDUTL("Provider "_$$PROV())
 D MES^XPDUTL("Pharmacist "_$$PHARM())
 D MES^XPDUTL("Nurse "_$$NURSE())
 ;
intro ; Update Intro Text
 D POSTINTRO
 QUIT
 ;
PROV() ;[Public $$] Create Generic Provider for Patients
 ; ASSUMPTION: DUZ MUST HAVE XUMGR OTHERWISE FILEMAN WILL BLOCK YOU!
 N NAME S NAME="PROVIDER,CLYDE WV" ; Constant
 Q:$O(^VA(200,"B",NAME,0)) $O(^(0)) ; Quit if the entry exists with entry
 ;
 N C0XFDA,C0XIEN,C0XERR,DIERR
 S C0XFDA(200,"?+1,",.01)=NAME
 S C0XFDA(200,"?+1,",1)="CWP" ; Initials
 S C0XFDA(200,"?+1,",28)=100 ; Mail Code
 S C0XFDA(200,"?+1,",53.1)=1 ; Authorized to write meds
 S C0XFDA(200.05,"?+2,?+1,",.01)="`144" ; Person Class - Allopathic docs.
 S C0XFDA(200.05,"?+2,?+1,",2)=2700101 ; Date active
 ;
 ; Security keys
 S C0XFDA(200.051,"?+3,?+1,",.01)="PROVIDER"
 S C0XFDA(200.051,"?+4,?+1,",.01)="ORES"
 ;
 ; Access and Verify Codes so we can log in as the provider if we want to
 ; We must pre-hash them as that's not in the IT
 S C0XFDA(200,"?+1,",2)=$$EN^XUSHSH("PROV123") ; ac
 S C0XFDA(200,"?+1,",11)=$$EN^XUSHSH("PROV123!!") ; vc
 S C0XFDA(200,"?+1,",7.2)=1 ; verify code never expires
 ;
 ; Electronic Signature
 ; Input transform hashes this guy
 S C0XFDA(200,"?+1,",20.4)="123456"
 ;
 ; Primary Menu
 S C0XFDA(200,"?+1,",201)="`"_$$FIND1^DIC(19,,"QX","XUCORE","B")
 ;
 ; Secondary Menu (CPRS, etc)
 S C0XFDA(200.03,"?+5,?+1,",.01)="`"_$$FIND1^DIC(19,,"QX","OR CPRS GUI CHART","B")
 ;
 ; Restrict Patient Selection
 S C0XFDA(200,"?+1,",101.01)="NO"
 ;
 ; CPRS Tabs
 S C0XFDA(200.010113,"?+6,?+1,",.01)="COR"
 S C0XFDA(200.010113,"?+6,?+1,",.02)="T-1"
 ;
 ; Service/Section
 S C0XFDA(200,"?+1,",29)="`"_$$MEDSS()
 ;
 ; NPI - Ferdi made this one up.
 S C0XFDA(200,"?+1,",41.99)="9990000348"
 ;
 N DIC S DIC(0)="" ; An XREF in File 200 requires this.
 D UPDATE^DIE("E",$NA(C0XFDA),$NA(C0XIEN),$NA(C0XERR)) ; Typical UPDATE
 I $D(DIERR) S $EC=",U1,"
 ;
 ; Fix verify code change date to the far future
 N FDA
 S FDA(200,C0XIEN(1)_",",11.2)=$$FMTH^XLFDT($$FMADD^XLFDT(DT,3000))
 ;
 ; Signature block. Do this as internal values to prevent name check in 20.2.
 S FDA(200,C0XIEN(1)_",",20.2)="CLYDE PROVIDER, MD"
 S FDA(200,C0XIEN(1)_",",20.3)="Staff Physician"
 ;
 D FILE^DIE(,$NA(FDA))
 I $D(DIERR) S $EC=",U1,"
 ;
 Q C0XIEN(1) ;Provider IEN
 ;
PHARM() ;[Public $$] Create Generic Provider for Synthetic Patients
 ; ASSUMPTION: DUZ MUST HAVE XUMGR OTHERWISE FILEMAN WILL BLOCK YOU!
 N NAME S NAME="PHARMACIST,LINDA WV" ; Constant
 Q:$O(^VA(200,"B",NAME,0)) $O(^(0)) ; Quit if the entry exists with entry
 ;
 N C0XFDA,C0XIEN,C0XERR,DIERR
 S C0XFDA(200,"?+1,",.01)=NAME
 S C0XFDA(200,"?+1,",1)="LWP" ; Initials
 S C0XFDA(200,"?+1,",28)=111 ; Mail Code
 S C0XFDA(200.05,"?+2,?+1,",.01)="`246" ; Person Class - Pharmacist
 S C0XFDA(200.05,"?+2,?+1,",2)=2700101 ; Date active
 ;
 ; Security keys
 S C0XFDA(200.051,"?+3,?+1,",.01)="PSORPH"
 S C0XFDA(200.051,"?+13,?+1,",.01)="PROVIDER"
 S C0XFDA(200.051,"?+4,?+1,",.01)="ORELSE"
 ;
 ; Access and Verify Codes so we can log in as the provider if we want to
 ; We must pre-hash them as that's not in the IT
 S C0XFDA(200,"?+1,",2)=$$EN^XUSHSH("PHARM123") ; ac
 S C0XFDA(200,"?+1,",11)=$$EN^XUSHSH("PHARM123!!") ; vc
 S C0XFDA(200,"?+1,",7.2)=1 ; verify code never expires
 ;
 ; Electronic Signature
 ; Input transform hashes this guy
 S C0XFDA(200,"?+1,",20.4)="123456"
 ;
 ; Primary Menu
 S C0XFDA(200,"?+1,",201)="`"_$$FIND1^DIC(19,,"QX","XUCORE","B")
 ;
 ; Secondary Menu (CPRS, etc)
 S C0XFDA(200.03,"?+5,?+1,",.01)="`"_$$FIND1^DIC(19,,"QX","OR CPRS GUI CHART","B")
 ;
 ; Restrict Patient Selection
 S C0XFDA(200,"?+1,",101.01)="NO"
 ;
 ; CPRS Tabs
 S C0XFDA(200.010113,"?+6,?+1,",.01)="COR"
 S C0XFDA(200.010113,"?+6,?+1,",.02)="T-1"
 ;
 ; Service/Section
 S C0XFDA(200,"?+1,",29)="`"_$$PHRSS()
 ;
 N DIC S DIC(0)="" ; An XREF in File 200 requires this.
 D UPDATE^DIE("E",$NA(C0XFDA),$NA(C0XIEN),$NA(C0XERR)) ; Typical UPDATE
 I $D(DIERR) S $EC=",U1,"
 ;
 ; Fix verify code change date to the far future
 N FDA
 S FDA(200,C0XIEN(1)_",",11.2)=$$FMTH^XLFDT($$FMADD^XLFDT(DT,3000))
 ;
 ; Signature block. Do this as internal values to prevent name check in 20.2.
 S FDA(200,C0XIEN(1)_",",20.2)="LINDA PHARMACIST, RPH"
 S FDA(200,C0XIEN(1)_",",20.3)="Staff Pharmacist"
 ;
 D FILE^DIE(,$NA(FDA))
 I $D(DIERR) S $EC=",U1,"
 ;
 Q C0XIEN(1) ;Provider IEN
 ;
NURSE() ; [Public $$] Create a nurse
 ; ASSUMPTION: DUZ MUST HAVE XUMGR OTHERWISE FILEMAN WILL BLOCK YOU!
 N NAME S NAME="NURSE,HELEN WV" ; Constant
 Q:$O(^VA(200,"B",NAME,0)) $O(^(0)) ; Quit if the entry exists with entry
 ;
 N C0XFDA,C0XIEN,C0XERR,DIERR
 S C0XFDA(200,"?+1,",.01)=NAME
 S C0XFDA(200,"?+1,",1)="HWN" ; Initials
 S C0XFDA(200,"?+1,",28)=100 ; Mail Code
 S C0XFDA(200.05,"?+2,?+1,",.01)="`276" ; Person Class - Nurse
 S C0XFDA(200.05,"?+2,?+1,",2)=2700101 ; Date active
 ;
 ; Security keys
 S C0XFDA(200.051,"?+3,?+1,",.01)="PROVIDER"
 S C0XFDA(200.051,"?+4,?+1,",.01)="ORELSE"
 ;
 ; Access and Verify Codes so we can log in as the provider if we want to
 ; We must pre-hash them as that's not in the IT
 S C0XFDA(200,"?+1,",2)=$$EN^XUSHSH("NURSE123") ; ac
 S C0XFDA(200,"?+1,",11)=$$EN^XUSHSH("NURSE123!!") ; vc
 S C0XFDA(200,"?+1,",7.2)=1 ; verify code never expires
 ;
 ; Electronic Signature
 ; Input transform hashes this guy
 S C0XFDA(200,"?+1,",20.4)="123456"
 ;
 ; Primary Menu
 S C0XFDA(200,"?+1,",201)="`"_$$FIND1^DIC(19,,"QX","XUCORE","B")
 ;
 ; Secondary Menu (CPRS, etc)
 S C0XFDA(200.03,"?+5,?+1,",.01)="`"_$$FIND1^DIC(19,,"QX","OR CPRS GUI CHART","B")
 ;
 ; Restrict Patient Selection
 S C0XFDA(200,"?+1,",101.01)="NO"
 ;
 ; CPRS Tabs
 S C0XFDA(200.010113,"?+6,?+1,",.01)="COR"
 S C0XFDA(200.010113,"?+6,?+1,",.02)="T-1"
 ;
 ; Service/Section
 S C0XFDA(200,"?+1,",29)="`"_$$MEDSS()
 ;
 N DIC S DIC(0)="" ; An XREF in File 200 requires this.
 D UPDATE^DIE("E",$NA(C0XFDA),$NA(C0XIEN),$NA(C0XERR)) ; Typical UPDATE
 I $D(DIERR) S $EC=",U1,"
 ;
 ; Fix verify code change date to the far future
 N FDA
 S FDA(200,C0XIEN(1)_",",11.2)=$$FMTH^XLFDT($$FMADD^XLFDT(DT,3000))
 ;
 ; Signature block. Do this as internal values to prevent name check in 20.2.
 S FDA(200,C0XIEN(1)_",",20.2)="HELEN NURSE, RPH"
 S FDA(200,C0XIEN(1)_",",20.3)="Staff Nurse"
 ;
 D FILE^DIE(,$NA(FDA))
 I $D(DIERR) S $EC=",U1,"
 ;
 Q C0XIEN(1) ;Provider IEN
 ;
MEDSS() ; [Public $$] Create Medical Service/Section
 N NAME S NAME="MEDICINE"
 Q:$O(^DIC(49,"B",NAME,0)) $O(^(0))
 ;
 N FDA,IEN,DIERR
 S FDA(49,"?+1,",.01)=NAME
 S FDA(49,"?+1,",1)="MED"
 S FDA(49,"?+1,",1.5)="MED"
 S FDA(49,"?+1,",1.7)="PATIENT CARE"
 D UPDATE^DIE("E",$NA(FDA),$NA(IEN))
 I $D(DIERR) S $EC=",U1,"
 QUIT IEN(1)
 ;
PHRSS() ; [Public $$] Create Pharmacy Service/Section
 N NAME S NAME="PHARMACY"
 Q:$O(^DIC(49,"B",NAME,0)) $O(^(0))
 ;
 N FDA,IEN,DIERR
 S FDA(49,"?+1,",.01)=NAME
 S FDA(49,"?+1,",1)="PHR"
 S FDA(49,"?+1,",1.5)="PHR"
 S FDA(49,"?+1,",1.6)="`"_$$MEDSS()
 S FDA(49,"?+1,",1.7)="PATIENT CARE"
 D UPDATE^DIE("E",$NA(FDA),$NA(IEN))
 I $D(DIERR) S $EC=",U1,"
 QUIT IEN(1)
 ;
POSTINTRO ; [Private] Append Users to Intro Text
 N DONE S DONE=0
 N I F I=0:0 S I=$O(^XTV(8989.3,1,"INTRO",I)) Q:'I  I ^(I,0)["PHARMACIST,L" S DONE=1 QUIT
 I DONE QUIT
 ;
 N SRC
 N % S %=$$GET1^DIQ(8989.3,"1,",240,"","SRC")
 ;
 N OUT
 S OUT(1)=SRC(1)
 S OUT(2)=" "
 N I,J,T S J=3 F I=1:1 S T=$P($T(INTROTXT+I),";;",2) Q:T="END"  S OUT(J)=T,J=J+1
 S OUT(J)=" ",J=J+1
 ;
 N I S I=1 F  S I=$O(SRC(I)) Q:'I  S OUT(J)=SRC(I),J=J+1
 ;
 D WP^DIE(8989.3,"1,",240,"","OUT")
 QUIT
 ;
INTROTXT ;
 ;; WV USER       ACCESS CODE    VERIFY CODE         ELECTRONIC SIGNATURE
 ;; --------      -----------    -----------         --------------------
 ;; PROVIDER,C    PROV123        PROV123!!           123456
 ;; PHARMACIST,L  PHARM123       PHARM123!!          123456
 ;; NURSE,H       NURSE123       NURSE123!!          123456
 ;;END
