          05 LCTFM412.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID-FILTER  PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID-SINCE   PIC S9(9) USAGE COMP-5.
             10 REQCHALLENGEID-SINCE PIC S9(9) USAGE COMP-5.
             10 PREREQ-COUNT        PIC S9(4) USAGE COMP-5.
             10 PREREQ-ENTRY OCCURS 20 TIMES
                  DEPENDING ON PREREQ-COUNT.
                15 EVENTID             PIC S9(9) USAGE COMP-5.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 REQCHALLENGEID      PIC S9(9) USAGE COMP-5.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
