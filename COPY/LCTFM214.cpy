          05 LCTFM214.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID-SINCE   PIC S9(9) USAGE COMP-5.
             10 SOLVE-COUNT         PIC S9(4) USAGE COMP-5.
             10 SOLVE-ENTRY OCCURS 20 TIMES
                  DEPENDING ON SOLVE-COUNT.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 CHALLENGETITLE.
                   49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                   49 CHALLENGETITLE-TEXT PIC N(100).
                15 CURRENTPOINTS       PIC S9(9) USAGE COMP-5.
                15 SOLVEDBY.
                   49 SOLVEDBY-LEN PIC S9(4) USAGE COMP-5.
                   49 SOLVEDBY-TEXT PIC N(30).
                15 SOLVEDDATE          PIC N(26).
