      ******************************************************************
      * DCLGEN TABLE(TBCTF004)                                         *
      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN        *
      ******************************************************************
           EXEC SQL DECLARE TBCTF004 TABLE
           ( PROVJOBID                      INTEGER NOT NULL,
             PLAYERID                       INTEGER NOT NULL,
             EVENTID                        INTEGER,
             PROVACTION                     GRAPHIC(1) NOT NULL,
             RACFGROUP                      GRAPHIC(8),
             JOBSTATUS                      GRAPHIC(1) NOT NULL,
             JESJOBID                       GRAPHIC(8),
             SUBMITTEDDATE                  TIMESTAMP,
             COMPLETEDDATE                  TIMESTAMP,
             JOBRC                          SMALLINT,
             JOBMESSAGE                     VARGRAPHIC(72),
             RETRYCOUNT                     SMALLINT NOT NULL,
             JOBHASH                        BINARY(32),
             CREATEDBY                      GRAPHIC(8) NOT NULL,
             CREATEDDATE                    TIMESTAMP NOT NULL,
             UPDATEDBY                      GRAPHIC(8) NOT NULL,
             UPDATEDDATE                    TIMESTAMP NOT NULL
           ) END-EXEC.
       01  DCLTBCTF004.
           10 PROVJOBID            PIC S9(9) USAGE COMP-5.
           10 PLAYERID             PIC S9(9) USAGE COMP-5.
           10 EVENTID              PIC S9(9) USAGE COMP-5.
           10 EVENTID-IND          PIC S9(4) USAGE COMP-5.
           10 PROVACTION           PIC N(1).
           10 RACFGROUP            PIC N(8).
           10 RACFGROUP-IND        PIC S9(4) USAGE COMP-5.
           10 JOBSTATUS            PIC N(1).
           10 JESJOBID             PIC N(8).
           10 JESJOBID-IND         PIC S9(4) USAGE COMP-5.
           10 SUBMITTEDDATE        PIC X(26).
           10 SUBMITTEDDATE-IND    PIC S9(4) USAGE COMP-5.
           10 COMPLETEDDATE        PIC X(26).
           10 COMPLETEDDATE-IND    PIC S9(4) USAGE COMP-5.
           10 JOBRC                PIC S9(4) USAGE COMP-5.
           10 JOBRC-IND            PIC S9(4) USAGE COMP-5.
           10 JOBMESSAGE.
              49 JOBMESSAGE-LEN PIC S9(4) USAGE COMP-5.
              49 JOBMESSAGE-TEXT PIC N(72).
           10 JOBMESSAGE-IND       PIC S9(4) USAGE COMP-5.
           10 RETRYCOUNT           PIC S9(4) USAGE COMP-5.
           10 JOBHASH              PIC X(32).
           10 JOBHASH-IND          PIC S9(4) USAGE COMP-5.
           10 CREATEDBY            PIC N(8).
           10 CREATEDDATE          PIC X(26).
           10 UPDATEDBY            PIC N(8).
           10 UPDATEDDATE          PIC X(26).
