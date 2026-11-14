      ******************************************************************
      * DCLGEN TABLE(TBCTF012)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF012 TABLE
           ( EVENTID                        INTEGER NOT NULL,
             CHALLENGEID                    INTEGER NOT NULL,
             REQCHALLENGEID                 INTEGER NOT NULL,
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF012.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 CHALLENGEID          PIC S9(9) USAGE COMP-5.
           10 REQCHALLENGEID       PIC S9(9) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
