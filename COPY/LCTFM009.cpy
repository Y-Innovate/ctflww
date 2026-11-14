          05 LCTFM009.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 HINTID              PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 SORTORDER           PIC S9(4) USAGE COMP-5.
             10 HINTTEXT.
                49 HINTTEXT-LEN PIC S9(4) USAGE COMP-5.
                49 HINTTEXT-TEXT PIC N(1000).
             10 COST                PIC S9(9) USAGE COMP-5.
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
