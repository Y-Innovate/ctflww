          05 LCTFM503.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 PLAYERID            PIC S9(9) USAGE COMP-5.
             10 RACFUSERID          PIC N(08).
             10 DISPLAYNAME.
                49 DISPLAYNAME-LEN PIC S9(4) USAGE COMP-5.
                49 DISPLAYNAME-TEXT PIC N(30).
             10 PLAYERSTATUS        PIC N.
             10 CLAIMEXPIRES        PIC N(26).
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
