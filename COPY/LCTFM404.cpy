          05 LCTFM404.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 JOBSTATUS-FILTER    PIC N.
             10 EVENTID-FILTER      PIC S9(9) USAGE COMP-5.
             10 PLAYERID-FILTER     PIC S9(9) USAGE COMP-5.
             10 PROVJOBID-SINCE     PIC S9(9) USAGE COMP-5.
             10 JOB-COUNT           PIC S9(4) USAGE COMP-5.
             10 JOB-ENTRY OCCURS 20 TIMES
                  DEPENDING ON JOB-COUNT.
                15 PROVJOBID           PIC S9(9) USAGE COMP-5.
                15 PLAYERID            PIC S9(9) USAGE COMP-5.
                15 EVENTID             PIC S9(9) USAGE COMP-5.
                15 PROVACTION          PIC N.
                15 RACFGROUP           PIC N(08).
                15 JOBSTATUS           PIC N.
                15 JESJOBID            PIC N(08).
                15 SUBMITTEDDATE       PIC N(26).
                15 COMPLETEDDATE       PIC N(26).
                15 JOBRC               PIC S9(9) USAGE COMP-3.
                15 JOBMESSAGE.
                   49 JOBMESSAGE-LEN PIC S9(4) USAGE COMP-5.
                   49 JOBMESSAGE-TEXT PIC N(72).
                15 RETRYCOUNT          PIC S9(4) USAGE COMP-5.
                15 CREATEDBY           PIC N(08).
                15 CREATEDDATE         PIC N(26).
                15 UPDATEDBY           PIC N(08).
                15 UPDATEDDATE         PIC N(26).
