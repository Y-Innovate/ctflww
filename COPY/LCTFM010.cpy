          05 LCTFM010.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 LINKID              PIC S9(9) USAGE COMP-5.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 LINKNAME.
                49 LINKNAME-LEN PIC S9(4) USAGE COMP-5.
                49 LINKNAME-TEXT PIC N(60).
             10 LINKURL.
                49 LINKURL-LEN PIC S9(4) USAGE COMP-5.
                49 LINKURL-TEXT PIC N(500).
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
