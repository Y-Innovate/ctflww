          05 LCTFM413.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 TEAMID-FILTER       PIC S9(9) USAGE COMP-5.
             10 PLAYERID-FILTER     PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID-FILTER  PIC S9(9) USAGE COMP-5.
             10 ISCORRECT-FILTER    PIC N.
             10 SUBMISSIONID-SINCE  PIC S9(9) USAGE COMP-5.
             10 SUBM-COUNT          PIC S9(4) USAGE COMP-5.
             10 SUBM-ENTRY OCCURS 20 TIMES
                  DEPENDING ON SUBM-COUNT.
                15 SUBMISSIONID        PIC S9(9) USAGE COMP-5.
                15 EVENTID             PIC S9(9) USAGE COMP-5.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 TEAMID              PIC S9(9) USAGE COMP-5.
                15 PLAYERID            PIC S9(9) USAGE COMP-5.
                15 SUBMITTEDTEXT.
                   49 SUBMITTEDTEXT-LEN PIC S9(4) USAGE COMP-5.
                   49 SUBMITTEDTEXT-TEXT PIC N(255).
                15 ISCORRECT           PIC N.
                15 REVERSEDBY          PIC N(08).
                15 REVERSEDDATE        PIC N(26).
                15 REVERSEREASON.
                   49 REVERSEREASON-LEN PIC S9(4) USAGE COMP-5.
                   49 REVERSEREASON-TEXT PIC N(255).
                15 CREATEDDATE         PIC N(26).
