          05 LCTFM407.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 CATEGORY-FILTER     PIC N(08).
             10 CHALLENGEID-SINCE   PIC S9(9) USAGE COMP-5.
             10 CHALLENGE-COUNT     PIC S9(4) USAGE COMP-5.
             10 CHALLENGE-ENTRY OCCURS 20 TIMES
                  DEPENDING ON CHALLENGE-COUNT.
                15 CHALLENGEID         PIC S9(9) USAGE COMP-5.
                15 CHALLENGETITLE.
                   49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
                   49 CHALLENGETITLE-TEXT PIC N(100).
                15 CATEGORY            PIC N(08).
                15 CHALLENGETYPE       PIC N.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
