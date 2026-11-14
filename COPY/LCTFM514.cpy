          05 LCTFM514.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 TEAMID              PIC S9(9) USAGE COMP-5.
             10 REVERSEREASON.
                49 REVERSEREASON-LEN PIC S9(4) USAGE COMP-5.
                49 REVERSEREASON-TEXT PIC N(255).
