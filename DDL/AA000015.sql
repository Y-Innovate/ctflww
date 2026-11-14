-- Create prereqs table in ctf database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create prereqs tablespace
   CREATE TABLESPACE {{PREREQS_TBSNAME}}
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

-- Create prereqs table
   CREATE TABLE {{SCHEMA}}.{{PREREQS_TBNAME}}
      (EVENTID        INTEGER NOT NULL,
       CHALLENGEID    INTEGER NOT NULL,
       REQCHALLENGEID INTEGER NOT NULL,
       CREATEDBY      GRAPHIC(8) NOT NULL,
       CREATEDDATE    TIMESTAMP NOT NULL,
       UPDATEDBY      GRAPHIC(8) NOT NULL,
       UPDATEDDATE    TIMESTAMP NOT NULL,
       CONSTRAINT PREREQSKEY
       PRIMARY KEY (EVENTID,
                    CHALLENGEID,
                    REQCHALLENGEID))
      IN {{DBNAME}}.{{PREREQS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create prereqs index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{PREREQS_IXNAME1}}
      ON {{SCHEMA}}.{{PREREQS_TBNAME}}
      (EVENTID        ASC,
       CHALLENGEID    ASC,
       REQCHALLENGEID ASC)
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

-- Create prereqs index on EVENTID, REQCHALLENGEID
   CREATE INDEX {{SCHEMA}}.{{PREREQS_IXNAME2}}
      ON {{SCHEMA}}.{{PREREQS_TBNAME}}
      (EVENTID        ASC,
       REQCHALLENGEID ASC)
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

-- Create foreign key on EVENTID, CHALLENGEID
   ALTER TABLE {{SCHEMA}}.{{PREREQS_TBNAME}}
     FOREIGN KEY PREREQ_FK1 (EVENTID,CHALLENGEID)
     REFERENCES {{SCHEMA}}.{{EVENTCHALL_TBNAME}}
       (EVENTID,CHALLENGEID)
     ON DELETE RESTRICT ENFORCED;

-- Create foreign key on EVENTID, REQCHALLENGEID
   ALTER TABLE {{SCHEMA}}.{{PREREQS_TBNAME}}
     FOREIGN KEY PREREQ_FK2 (EVENTID,REQCHALLENGEID)
     REFERENCES {{SCHEMA}}.{{EVENTCHALL_TBNAME}}
       (EVENTID,CHALLENGEID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;