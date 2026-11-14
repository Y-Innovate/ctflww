      ******************************************************************
      * DCLGEN TABLE(TBCTF010)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF010 TABLE
           ( LINKID                         INTEGER NOT NULL,
             CHALLENGEID                    INTEGER NOT NULL,
             LINKNAME                       VARGRAPHIC(60) NOT NULL,
             LINKURL                        VARGRAPHIC(500) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF010.
           10 LINKID               PIC S9(9) USAGE COMP-5.
           10 CHALLENGEID          PIC S9(9) USAGE COMP-5.
           10 LINKNAME.
              49 LINKNAME-LEN PIC S9(4) USAGE COMP-5.
              49 LINKNAME-TEXT PIC N(60).
           10 LINKURL.
              49 LINKURL-LEN PIC S9(4) USAGE COMP-5.
              49 LINKURL-TEXT PIC N(500).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
