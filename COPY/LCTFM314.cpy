          05 LCTFM314.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 RANK-SINCE          PIC S9(9) USAGE COMP-5.
             10 ISFROZEN            PIC N.
             10 ADMINVIEW           PIC N.
             10 BOARD-COUNT         PIC S9(4) USAGE COMP-5.
             10 BOARD-ENTRY OCCURS 20 TIMES
                  DEPENDING ON BOARD-COUNT.
                15 RANKNO              PIC S9(9) USAGE COMP-5.
                15 TEAMID              PIC S9(9) USAGE COMP-5.
                15 TEAMNAME.
                   49 TEAMNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 TEAMNAME-TEXT PIC N(30).
                15 SCORE               PIC S9(9) USAGE COMP-3.
                15 SOLVECOUNT          PIC S9(9) USAGE COMP-5.
