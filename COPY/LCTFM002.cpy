          05 LCTFM002.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 EVENTNAME.
                49 EVENTNAME-LEN PIC S9(4) USAGE COMP-5.
                49 EVENTNAME-TEXT PIC N(100).
             10 DESCRIPTION.
                49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 DESCRIPTION-TEXT PIC N(1000).
             10 EVENTSTATUS         PIC N.
             10 PLAYMODE            PIC N.
             10 MAXTEAMSIZE         PIC S9(4) USAGE COMP-5.
             10 STARTTS             PIC N(26).
             10 ENDTS               PIC N(26).
             10 FREEZETS            PIC N(26).
             10 REGCODE.
                49 REGCODE-LEN PIC S9(4) USAGE COMP-5.
                49 REGCODE-TEXT PIC N(32).
             10 REGFROMTS           PIC N(26).
             10 REGTOTS             PIC N(26).
             10 MAXPLAYERS          PIC S9(9) USAGE COMP-5.
             10 PLAYERCOUNT         PIC S9(9) USAGE COMP-5.
             10 RACFGROUP           PIC N(08).
             10 PHASE               PIC N.
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
