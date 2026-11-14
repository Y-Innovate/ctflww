          05 LCTFM405.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 TEAMID-SINCE        PIC S9(9) USAGE COMP-5.
             10 TEAM-COUNT          PIC S9(4) USAGE COMP-5.
             10 TEAM-ENTRY OCCURS 20 TIMES
                  DEPENDING ON TEAM-COUNT.
                15 TEAMID              PIC S9(9) USAGE COMP-5.
                15 TEAMNAME.
                   49 TEAMNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 TEAMNAME-TEXT PIC N(30).
                15 CAPTAINID           PIC S9(9) USAGE COMP-5.
                15 MEMBERCOUNT         PIC S9(4) USAGE COMP-5.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
