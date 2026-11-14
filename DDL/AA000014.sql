-- Create eventchall table in ctf database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create eventchall tablespace
   CREATE TABLESPACE {{EVENTCHALL_TBSNAME}}
                       IN {{DBNAME}}
                       USING STOGROUP {{STOGROUP}}
                       PRIQTY 40 SECQTY 40
                       ERASE  NO
                       FREEPAGE 0 PCTFREE 5 FOR UPDATE 0
                       GBPCACHE CHANGED
                       TRACKMOD YES
                       MAXPARTITIONS 254
                       LOGGED
                       DSSIZE 4 G
                       SEGSIZE 4
                       BUFFERPOOL BP0
                       LOCKSIZE ANY
                       LOCKMAX SYSTEM
                       CLOSE YES
                       COMPRESS NO
                       CCSID      UNICODE
                       DEFINE YES
                       MAXROWS 255
                       INSERT ALGORITHM 0;

-- Create eventchall table
   CREATE TABLE {{SCHEMA}}.{{EVENTCHALL_TBNAME}}
      (EVENTID     INTEGER NOT NULL,
       CHALLENGEID INTEGER NOT NULL,
       SCORETYPE   GRAPHIC(1) NOT NULL,
       INITPOINTS  INTEGER NOT NULL,
       MINPOINTS   INTEGER,
       DECAYSOLVES INTEGER,
       ISVISIBLE   GRAPHIC(1) NOT NULL,
       SORTORDER   SMALLINT NOT NULL,
       MAXATTEMPTS SMALLINT,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT EVENTCHALLKEY
       PRIMARY KEY (EVENTID,
                    CHALLENGEID))
      IN {{DBNAME}}.{{EVENTCHALL_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create eventchall index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{EVENTCHALL_IXNAME1}}
      ON {{SCHEMA}}.{{EVENTCHALL_TBNAME}}
      (EVENTID     ASC,
       CHALLENGEID ASC)
     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;

-- Create eventchall index on CHALLENGEID
   CREATE INDEX {{SCHEMA}}.{{EVENTCHALL_IXNAME2}}
      ON {{SCHEMA}}.{{EVENTCHALL_TBNAME}}
      (CHALLENGEID ASC)
     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;

-- Create foreign key on EVENTID
   ALTER TABLE {{SCHEMA}}.{{EVENTCHALL_TBNAME}}
     FOREIGN KEY EVENTC_FK1 (EVENTID)
     REFERENCES {{SCHEMA}}.{{EVENTS_TBNAME}}
       (EVENTID)
     ON DELETE RESTRICT ENFORCED;

-- Create foreign key on CHALLENGEID
   ALTER TABLE {{SCHEMA}}.{{EVENTCHALL_TBNAME}}
     FOREIGN KEY EVENTC_FK2 (CHALLENGEID)
     REFERENCES {{SCHEMA}}.{{CHALLENGES_TBNAME}}
       (CHALLENGEID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;