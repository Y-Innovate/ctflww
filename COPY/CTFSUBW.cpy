      *===============================================================*
      * CTFSUBW: Working storage for CTFSUBP, which starts the task   *
      * that submits a provisioning job. The module fills in          *
      * W-LCTFC910: the settings, PROVJOBID, PLAYERID and JOBTOKEN.   *
      *===============================================================*
       01 W-SUBMIT.
          05 C-CHNL-NAME-SUBMIT PIC X(16) VALUE 'CTFSUBMIT'.
          05 C-CONT-NAME-SUBMIT PIC X(16) VALUE 'LCTFC911'.
       01 W-LCTFM910.
           COPY LCTFM910.
       01 W-LCTFC910.
           COPY LCTFC910.
       01 W-LCTFC911.
           COPY LCTFC911.
