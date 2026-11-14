      ******************************************************************
      * DCLGEN TABLE(TBCTF008)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF008 TABLE
           ( FLAGID                         INTEGER NOT NULL,
             CHALLENGEID                    INTEGER NOT NULL,
             FLAGVALUE                      VARGRAPHIC(255) NOT NULL,
             CASESENSITIVE                  GRAPHIC(1) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF008.
           10 FLAGID               PIC S9(9) USAGE COMP-5.
           10 CHALLENGEID          PIC S9(9) USAGE COMP-5.
           10 FLAGVALUE.
              49 FLAGVALUE-LEN PIC S9(4) USAGE COMP-5.
              49 FLAGVALUE-TEXT PIC N(255).
           10 CASESENSITIVE        PIC N(1).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
