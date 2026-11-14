      ******************************************************************
      * DCLGEN TABLE(TBCTF009)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF009 TABLE
           ( HINTID                         INTEGER NOT NULL,
             CHALLENGEID                    INTEGER NOT NULL,
             SORTORDER                      SMALLINT NOT NULL,
             HINTTEXT                       VARGRAPHIC(1000) NOT NULL,
             COST                           INTEGER NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF009.
           10 HINTID               PIC S9(9) USAGE COMP-5.
           10 CHALLENGEID          PIC S9(9) USAGE COMP-5.
           10 SORTORDER            PIC S9(4) USAGE COMP-5.
           10 HINTTEXT.
              49 HINTTEXT-LEN PIC S9(4) USAGE COMP-5.
              49 HINTTEXT-TEXT PIC N(1000).
           10 COST                 PIC S9(9) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
