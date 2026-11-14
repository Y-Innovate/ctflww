          05 LCTFM202.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID-SINCE       PIC S9(9) USAGE COMP-5.
             10 EVENT-COUNT         PIC S9(4) USAGE COMP-5.
             10 EVENT-ENTRY OCCURS 20 TIMES
                  DEPENDING ON EVENT-COUNT.
                15 EVENTID             PIC S9(9) USAGE COMP-5.
                15 EVENTNAME.
                   49 EVENTNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 EVENTNAME-TEXT PIC N(100).
                15 EVENTSTATUS         PIC N.
                15 PHASE               PIC N.
                15 PLAYMODE            PIC N.
                15 MAXTEAMSIZE         PIC S9(4) USAGE COMP-5.
                15 STARTTS             PIC N(26).
                15 ENDTS               PIC N(26).
                15 FREEZETS            PIC N(26).
                15 REGFROMTS           PIC N(26).
                15 REGTOTS             PIC N(26).
                15 REGOPEN             PIC N.
