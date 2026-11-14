          05 LCTFM011.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 CHALLENGETITLE.
                49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                49 CHALLENGETITLE-TEXT PIC N(100).
             10 SCORETYPE           PIC N.
             10 INITPOINTS          PIC S9(9) USAGE COMP-5.
             10 MINPOINTS           PIC S9(9) USAGE COMP-5.
             10 DECAYSOLVES         PIC S9(9) USAGE COMP-5.
             10 ISVISIBLE           PIC N.
             10 SORTORDER           PIC S9(4) USAGE COMP-5.
             10 MAXATTEMPTS         PIC S9(4) USAGE COMP-5.
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
