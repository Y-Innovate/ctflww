          05 LCTFM205.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 PLAYERID-SINCE      PIC S9(9) USAGE COMP-5.
             10 MEMBER-COUNT        PIC S9(4) USAGE COMP-5.
             10 MEMBER-ENTRY OCCURS 20 TIMES
                  DEPENDING ON MEMBER-COUNT.
                15 PLAYERID            PIC S9(9) USAGE COMP-5.
                15 DISPLAYNAME.
                   49 DISPLAYNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 DISPLAYNAME-TEXT PIC N(30).
                15 ISCAPTAIN           PIC N.
