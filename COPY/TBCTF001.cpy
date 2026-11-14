      ******************************************************************
      * DCLGEN TABLE(TBCTF001)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF001 TABLE
           ( TABLEID                        GRAPHIC(8) NOT NULL,
             TABKEY                         GRAPHIC(8) NOT NULL,
             TABVALUE                       VARGRAPHIC(255),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF001.
           10 TABLEID              PIC N(8).
           10 TABKEY               PIC N(8).
           10 TABVALUE.
              49 TABVALUE-LEN PIC S9(4) USAGE COMP-5.
              49 TABVALUE-TEXT PIC N(255).
           10 TABVALUE-IND         PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
