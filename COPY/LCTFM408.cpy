          05 LCTFM408.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 CHALLENGEID-FILTER  PIC S9(9) USAGE COMP-5.
             10 FLAGID-SINCE        PIC S9(9) USAGE COMP-5.
             10 FLAG-COUNT          PIC S9(4) USAGE COMP-5.
             10 FLAG-ENTRY OCCURS 20 TIMES
                  DEPENDING ON FLAG-COUNT.
                15 FLAGID              PIC S9(9) USAGE COMP-5.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 FLAGVALUE.
                   49 FLAGVALUE-LEN PIC S9(4) USAGE COMP-5.
                   49 FLAGVALUE-TEXT PIC N(255).
                15 CASESENSITIVE       PIC N.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
