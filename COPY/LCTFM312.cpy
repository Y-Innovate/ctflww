          05 LCTFM312.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 CHALLENGETITLE.
                49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                49 CHALLENGETITLE-TEXT PIC N(100).
             10 CATEGORY            PIC N(08).
             10 CATEGORYNAME.
                49 CATEGORYNAME-LEN PIC S9(4) USAGE COMP-5.
                49 CATEGORYNAME-TEXT PIC N(255).
             10 DESCRIPTION.
                49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 DESCRIPTION-TEXT PIC N(3000).
             10 CURRENTPOINTS       PIC S9(9) USAGE COMP-5.
             10 SOLVECOUNT          PIC S9(9) USAGE COMP-5.
             10 ISSOLVED            PIC N.
             10 ATTEMPTSLEFT        PIC S9(9) USAGE COMP-3.
