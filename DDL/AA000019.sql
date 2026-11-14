-- Create awards table in ctf database.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

-- Create awards tablespace
   CREATE TABLESPACE {{AWARDS_TBSNAME}}
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

-- Create awards table
   CREATE TABLE {{SCHEMA}}.{{AWARDS_TBNAME}}
      (AWARDID     INTEGER NOT NULL GENERATED ALWAYS
          AS IDENTITY
             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,
              NO ORDER, MAXVALUE 2147483647, MINVALUE 1),
       EVENTID     INTEGER NOT NULL,
       TEAMID      INTEGER NOT NULL,
       POINTS      INTEGER NOT NULL,
       REASON      VARGRAPHIC(255) NOT NULL,
       CREATEDBY   GRAPHIC(8) NOT NULL,
       CREATEDDATE TIMESTAMP NOT NULL,
       UPDATEDBY   GRAPHIC(8) NOT NULL,
       UPDATEDDATE TIMESTAMP NOT NULL,
       CONSTRAINT AWARDSKEY
       PRIMARY KEY (AWARDID))
      IN {{DBNAME}}.{{AWARDS_TBSNAME}}
      PARTITION BY SIZE
      AUDIT NONE
      DATA CAPTURE NONE
      CCSID      UNICODE
      NOT VOLATILE
      APPEND NO;

-- Create awards index for primary key
   CREATE UNIQUE INDEX {{SCHEMA}}.{{AWARDS_IXNAME1}}
      ON {{SCHEMA}}.{{AWARDS_TBNAME}}
      (AWARDID ASC)
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

-- Create awards index on EVENTID, TEAMID
   CREATE INDEX {{SCHEMA}}.{{AWARDS_IXNAME2}}
      ON {{SCHEMA}}.{{AWARDS_TBNAME}}
      (EVENTID ASC,
       TEAMID  ASC)
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

-- Create awards index on TEAMID
   CREATE INDEX {{SCHEMA}}.{{AWARDS_IXNAME3}}
      ON {{SCHEMA}}.{{AWARDS_TBNAME}}
      (TEAMID ASC)
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
   ALTER TABLE {{SCHEMA}}.{{AWARDS_TBNAME}}
     FOREIGN KEY AWARDS_FK1 (EVENTID)
     REFERENCES {{SCHEMA}}.{{EVENTS_TBNAME}}
       (EVENTID)
     ON DELETE RESTRICT ENFORCED;

-- Create foreign key on TEAMID
   ALTER TABLE {{SCHEMA}}.{{AWARDS_TBNAME}}
     FOREIGN KEY AWARDS_FK2 (TEAMID)
     REFERENCES {{SCHEMA}}.{{TEAMS_TBNAME}}
       (TEAMID)
     ON DELETE RESTRICT ENFORCED;

   COMMIT;