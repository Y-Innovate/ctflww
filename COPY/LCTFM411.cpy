          05 LCTFM411.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID-SINCE   PIC S9(9) USAGE COMP-5.
             10 EVENTCHALL-COUNT    PIC S9(4) USAGE COMP-5.
             10 EVENTCHALL-ENTRY OCCURS 20 TIMES
                  DEPENDING ON EVENTCHALL-COUNT.
                15 EVENTID             PIC S9(9) USAGE COMP-5.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 CHALLENGETITLE.
                   49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                   49 CHALLENGETITLE-TEXT PIC N(100).
                15 SCORETYPE           PIC N.
                15 INITPOINTS          PIC S9(9) USAGE COMP-5.
                15 MINPOINTS           PIC S9(9) USAGE COMP-5.
                15 DECAYSOLVES         PIC S9(9) USAGE COMP-5.
                15 ISVISIBLE           PIC N.
                15 SORTORDER           PIC S9(4) USAGE COMP-5.
                15 MAXATTEMPTS         PIC S9(4) USAGE COMP-5.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
