          05 LCTFM007.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 OPCODE              PIC N.
             10 CHALLENGEID         PIC S9(9) USAGE COMP-5.
             10 CHALLENGETITLE.
                49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                49 CHALLENGETITLE-TEXT PIC N(100).
             10 CATEGORY            PIC N(08).
             10 DESCRIPTION.
                49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
                49 DESCRIPTION-TEXT PIC N(3000).
             10 CHALLENGETYPE       PIC N.
             10 VERIFIERPGM         PIC N(08).
             10 CREATEDBY           PIC N(08).
             10 CREATEDDATE         PIC N(26).
             10 UPDATEDBY           PIC N(08).
             10 UPDATEDDATE         PIC N(26).
