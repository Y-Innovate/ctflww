          05 LCTFM313.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 EVENTID             PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 FLAG.
                49 FLAG-LEN PIC S9(4) USAGE COMP-5.
                49 FLAG-TEXT PIC N(255).
             10 SUBMISSIONID        PIC S9(9) USAGE COMP-5.
             10 ISCORRECT           PIC N.
             10 ATTEMPTSLEFT        PIC S9(9) USAGE COMP-3.
