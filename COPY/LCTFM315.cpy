          05 LCTFM315.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 HINTID              PIC S9(9) USAGE COMP-5.
             10 COST                PIC S9(9) USAGE COMP-5.
             10 HINTTEXT.
                49 HINTTEXT-LEN PIC S9(4) USAGE COMP-5.
                49 HINTTEXT-TEXT PIC N(1000).
