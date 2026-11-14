-- Userid range per environment, for a database created before AA000006
-- had one: only the maximum changes, so the userids handed out so far
-- stay valid. Safe in an environment with players. The minimum follows
-- in AA000029, for an environment without players.

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

   ALTER SEQUENCE {{SCHEMA}}.{{PLAYERS_SEQNAME}}
      MAXVALUE {{PLAYERS_SEQ_MAX}};

   COMMIT;
