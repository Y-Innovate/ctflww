          05 LCTFM210.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 LINKID-SINCE        PIC S9(9) USAGE COMP-5.
             10 LINK-COUNT          PIC S9(4) USAGE COMP-5.
             10 LINK-ENTRY OCCURS 20 TIMES
                  DEPENDING ON LINK-COUNT.
                15 LINKID              PIC S9(9) USAGE COMP-5.
                15 LINKNAME.
                   49 LINKNAME-LEN PIC S9(4) USAGE COMP-5.
                   49 LINKNAME-TEXT PIC N(60).
                15 LINKURL.
                   49 LINKURL-LEN PIC S9(4) USAGE COMP-5.
                   49 LINKURL-TEXT PIC N(500).
