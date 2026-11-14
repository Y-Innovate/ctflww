      ******************************************************************
      * DCLGEN TABLE(TBCTF007)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF007 TABLE
           ( CHALLENGEID                    INTEGER NOT NULL,
             CHALLENGETITLE                 VARGRAPHIC(100) NOT NULL,
             CATEGORY                       GRAPHIC(8) NOT NULL,
             DESCRIPTION                    VARGRAPHIC(3000) NOT NULL,
             CHALLENGETYPE                  GRAPHIC(1) NOT NULL,
             VERIFIERPGM                    GRAPHIC(8),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF007.
           10 CHALLENGEID          PIC S9(9) USAGE COMP-5.
           10 CHALLENGETITLE.
              49 CHALLENGETITLE-LEN PIC S9(4) USAGE COMP-5.
              49 CHALLENGETITLE-TEXT PIC N(100).
           10 CATEGORY             PIC N(8).
           10 DESCRIPTION.
              49 DESCRIPTION-LEN PIC S9(4) USAGE COMP-5.
              49 DESCRIPTION-TEXT PIC N(3000).
           10 CHALLENGETYPE        PIC N(1).
           10 VERIFIERPGM          PIC N(8).
           10 VERIFIERPGM-IND      PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
