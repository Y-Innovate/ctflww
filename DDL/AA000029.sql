-- Move the userid sequence to the start of this environment's range.
-- ONLY for an environment without players yet (a new one, such as T02):
-- in one with players, CTFM303 would hand out userids from the start of
-- the range again, and they may exist already. Check first:
--   SELECT COUNT(*) FROM {{SCHEMA}}.{{PLAYERS_TBNAME}};

-- Set SQLID
   SET CURRENT SQLID='{{SQLID}}';

   ALTER SEQUENCE {{SCHEMA}}.{{PLAYERS_SEQNAME}}
      RESTART WITH {{PLAYERS_SEQ_START}}
      MINVALUE {{PLAYERS_SEQ_START}}
      MAXVALUE {{PLAYERS_SEQ_MAX}};

   COMMIT;
