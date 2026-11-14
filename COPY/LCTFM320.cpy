          05 LCTFM320.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 TEAMID              PIC S9(9) USAGE COMP-5.
             10 TEAMNAME.
                49 TEAMNAME-LEN PIC S9(4) USAGE COMP-5.
                49 TEAMNAME-TEXT PIC N(30).
             10 ISCAPTAIN           PIC N.
             10 JOINCODE            PIC N(12).
             10 MEMBERCOUNT         PIC S9(4) USAGE COMP-5.
             10 SCORE               PIC S9(9) USAGE COMP-3.
             10 SOLVECOUNT          PIC S9(9) USAGE COMP-5.
             10 HINTCOUNT           PIC S9(9) USAGE COMP-5.
