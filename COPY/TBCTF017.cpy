      ******************************************************************
      * DCLGEN TABLE(TBCTF017)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF017 TABLE
           ( ANNOUNCEID                     INTEGER NOT NULL,
             EVENTID                        INTEGER NOT NULL,
             ANNOUNCETITLE                  VARGRAPHIC(100) NOT NULL,
             BODY                           VARGRAPHIC(1000) NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF017.
           10 ANNOUNCEID           PIC S9(9) USAGE COMP-5.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 ANNOUNCETITLE.
              49 ANNOUNCETITLE-LEN PIC S9(4) USAGE COMP-5.
              49 ANNOUNCETITLE-TEXT PIC N(100).
           10 BODY.
              49 BODY-LEN PIC S9(4) USAGE COMP-5.
              49 BODY-TEXT PIC N(1000).
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
