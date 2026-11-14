          05 LCTFM303.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 REGCODE.
                49 REGCODE-LEN PIC S9(4) USAGE COMP-5.
                49 REGCODE-TEXT PIC N(32).
             10 DISPLAYNAME.
                49 DISPLAYNAME-LEN PIC S9(4) USAGE COMP-5.
                49 DISPLAYNAME-TEXT PIC N(30).
             10 REGISTRATIONID      PIC S9(9) USAGE COMP-5.
             10 CLAIMTOKEN          PIC N(64).
