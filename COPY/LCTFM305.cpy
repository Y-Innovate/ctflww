          05 LCTFM305.
             10 OPCODE              PIC N.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 REGISTRATIONID      PIC S9(9) USAGE COMP-5.
             10 CLAIMTOKEN          PIC N(64).
             10 PASSPHRASE.
                49 PASSPHRASE-LEN PIC S9(4) USAGE COMP-5.
                49 PASSPHRASE-TEXT PIC N(100).
             10 RACFUSERID          PIC N(08).
