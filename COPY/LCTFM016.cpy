          05 LCTFM016.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 AWARDID             PIC S9(9) USAGE COMP-5.
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 TEAMID              PIC S9(9) USAGE COMP-5.
             10 POINTS              PIC S9(9) USAGE COMP-3.
             10 REASON.
                49 REASON-LEN PIC S9(4) USAGE COMP-5.
                49 REASON-TEXT PIC N(255).
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
