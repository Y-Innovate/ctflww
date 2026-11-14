          05 LCTFM217.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 ANNOUNCEID-SINCE    PIC S9(9) USAGE COMP-5.
             10 ANNOUNCE-COUNT      PIC S9(4) USAGE COMP-5.
             10 ANNOUNCE-ENTRY OCCURS 20 TIMES
                  DEPENDING ON ANNOUNCE-COUNT.
                15 ANNOUNCEID          PIC S9(9) USAGE COMP-5.
                15 ANNOUNCETITLE.
                   49 ANNOUNCETITLE-LEN PIC S9(4) USAGE COMP-5.
                   49 ANNOUNCETITLE-TEXT PIC N(100).
                15 BODY.
                   49 BODY-LEN PIC S9(4) USAGE COMP-5.
                   49 BODY-TEXT PIC N(1000).
                15 CREATEDDATE         PIC N(26).
