          05 LCTFM209.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 SORTORDER-SINCE     PIC S9(4) USAGE COMP-5.
             10 HINTID-SINCE        PIC S9(9) USAGE COMP-5.
             10 HINT-COUNT          PIC S9(4) USAGE COMP-5.
             10 HINT-ENTRY OCCURS 20 TIMES
                  DEPENDING ON HINT-COUNT.
                15 HINTID              PIC S9(9) USAGE COMP-5.
                15 SORTORDER           PIC S9(4) USAGE COMP-5.
                15 COST                PIC S9(9) USAGE COMP-5.
                15 ISUNLOCKED          PIC N.
                15 HINTTEXT.
                   49 HINTTEXT-LEN PIC S9(4) USAGE COMP-5.
                   49 HINTTEXT-TEXT PIC N(1000).
