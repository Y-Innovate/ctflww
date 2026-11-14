          05 LCTFM008.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 FLAGID              PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 FLAGVALUE.
                49 FLAGVALUE-LEN PIC S9(4) USAGE COMP-5.
                49 FLAGVALUE-TEXT PIC N(255).
             10 CASESENSITIVE       PIC N.
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
