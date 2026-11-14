          05 LCTFM212.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 REQCHALLENGEID-SINCE PIC S9(9) USAGE COMP-5.
             10 PREREQ-COUNT        PIC S9(4) USAGE COMP-5.
             10 PREREQ-ENTRY OCCURS 20 TIMES
                  DEPENDING ON PREREQ-COUNT.
                15 REQCHALLENGEID      PIC S9(9) USAGE COMP-5.
                15 CHALLENGETITLE.
                   49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                   49 CHALLENGETITLE-TEXT PIC N(100).
                15 ISSOLVED            PIC N.
