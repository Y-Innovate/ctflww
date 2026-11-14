          05 LCTFM311.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 SORTORDER-SINCE     PIC S9(4) USAGE COMP-5.
             10 CHALLENGEID-SINCE   PIC S9(9) USAGE COMP-5.
             10 CHALL-COUNT         PIC S9(4) USAGE COMP-5.
             10 CHALL-ENTRY OCCURS 20 TIMES
                  DEPENDING ON CHALL-COUNT.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 CHALLENGETITLE.
                   49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                   49 CHALLENGETITLE-TEXT PIC N(100).
                15 CATEGORY            PIC N(08).
                15 CATEGORYNAME.
                   49 CATEGORYNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 CATEGORYNAME-TEXT PIC N(255).
                15 CURRENTPOINTS       PIC S9(9) USAGE COMP-5.
                15 SOLVECOUNT          PIC S9(9) USAGE COMP-5.
                15 ISSOLVED            PIC N.
                15 ISLOCKED            PIC N.
                15 SORTORDER           PIC S9(4) USAGE COMP-5.
