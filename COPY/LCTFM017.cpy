          05 LCTFM017.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 ANNOUNCEID          PIC S9(9) USAGE COMP-5.
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 ANNOUNCETITLE.
                49 ANNOUNCETITLE-LEN PIC S9(4) USAGE COMP-5.
                49 ANNOUNCETITLE-TEXT PIC N(100).
             10 BODY.
                49 BODY-LEN PIC S9(4) USAGE COMP-5.
                49 BODY-TEXT PIC N(1000).
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
