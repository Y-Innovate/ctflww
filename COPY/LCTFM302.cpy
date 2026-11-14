          05 LCTFM302.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 EVENTNAME.
                49 EVENTNAME-LEN PIC S9(4) USAGE COMP-5.
                49 EVENTNAME-TEXT PIC N(100).
             10 EVENTSTATUS         PIC N.
             10 PHASE               PIC N.
             10 PLAYMODE            PIC N.
             10 MAXTEAMSIZE         PIC S9(4) USAGE COMP-5.
             10 STARTTS             PIC N(26).
             10 ENDTS               PIC N(26).
             10 FREEZETS            PIC N(26).
             10 REGFROMTS           PIC N(26).
             10 REGTOTS             PIC N(26).
             10 REGOPEN             PIC N.
             10 DESCRIPTION.
                49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 DESCRIPTION-TEXT PIC N(1000).
