          05 LCTFM403.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 DISPLAYNAME-FILTER.
                49 DISPLAYNAME-FILTER-LEN PIC S9(4) USAGE COMP-5.
                49 DISPLAYNAME-FILTER-TEXT PIC N(30).
             10 RACFUSERID-FILTER   PIC N(08).
             10 PLAYERSTATUS-FILTER PIC N.
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 PLAYERID-SINCE      PIC S9(9) USAGE COMP-5.
             10 PLAYER-COUNT        PIC S9(4) USAGE COMP-5.
             10 PLAYER-ENTRY OCCURS 20 TIMES
                  DEPENDING ON PLAYER-COUNT.
                15 PLAYERID            PIC S9(9) USAGE COMP-5.
                15 RACFUSERID          PIC N(08).
                15 DISPLAYNAME.
                   49 DISPLAYNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 DISPLAYNAME-TEXT PIC N(30).
                15 PLAYERSTATUS        PIC N.
                15 CLAIMEXPIRES        PIC N(26).
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
