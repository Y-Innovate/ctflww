          05 LCTFM206.
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
                15 PHASE               PIC N.
                15 PLAYMODE            PIC N.
                15 PARTSTATUS          PIC N.
                15 TEAMID              PIC S9(9) USAGE COMP-5.
                15 TEAMNAME.
                   49 TEAMNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 TEAMNAME-TEXT PIC N(30).
