          05 LCTFM414.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 TEAMID-FILTER       PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID-FILTER  PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID-SINCE   PIC S9(9) USAGE COMP-5.
             10 TEAMID-SINCE        PIC S9(9) USAGE COMP-5.
             10 SOLVE-COUNT         PIC S9(4) USAGE COMP-5.
             10 SOLVE-ENTRY OCCURS 20 TIMES
                  DEPENDING ON SOLVE-COUNT.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 TEAMID              PIC S9(9) USAGE COMP-5.
                15 PLAYERID            PIC S9(9) USAGE COMP-5.
                15 SUBMISSIONID        PIC S9(9) USAGE COMP-5.
                15 CREATEDDATE         PIC N(26).
