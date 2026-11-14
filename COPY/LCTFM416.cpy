          05 LCTFM416.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 TEAMID-FILTER       PIC S9(9) USAGE COMP-5.
             10 AWARDID-SINCE       PIC S9(9) USAGE COMP-5.
             10 AWARD-COUNT         PIC S9(4) USAGE COMP-5.
             10 AWARD-ENTRY OCCURS 20 TIMES
                  DEPENDING ON AWARD-COUNT.
                15 AWARDID             PIC S9(9) USAGE COMP-5.
                15 EVENTID             PIC S9(9) USAGE COMP-5.
                15 TEAMID              PIC S9(9) USAGE COMP-5.
                15 POINTS              PIC S9(9) USAGE COMP-3.
                15 REASON.
                   49 REASON-LEN PIC S9(4) USAGE COMP-5.
                   49 REASON-TEXT PIC N(255).
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
