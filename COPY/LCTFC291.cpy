          05 LCTFC291.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 CURRENTPASSPHRASE.
                49 CURRENTPASSPHRASE-LEN PIC S9(4) USAGE COMP-5.
                49 CURRENTPASSPHRASE-TEXT PIC N(100).
             10 NEWPASSPHRASE.
                49 NEWPASSPHRASE-LEN PIC S9(4) USAGE COMP-5.
                49 NEWPASSPHRASE-TEXT PIC N(100).
