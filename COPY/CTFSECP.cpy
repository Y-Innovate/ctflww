      *===============================================================*
      * R800-NEW-TOKEN: Generate a random claim token in W-TOKEN      *
      *===============================================================*
       R800-NEW-TOKEN SECTION.
           SET FUNC-RANDOM TO TRUE
           CALL W-A991-PGM USING W-LCTFA991

           IF A991-OK
              PERFORM VARYING W-SEC-I FROM 1 BY 1 UNTIL W-SEC-I > 32
                 MOVE OUTPUT-DATA OF W-LCTFA991(W-SEC-I:1) TO W-SEC-BYTE
                 COMPUTE W-SEC-J = 2 * W-SEC-I - 1
                 COMPUTE W-SEC-K = W-SEC-BYTE-NUM / 16 + 1
                 MOVE C-HEX(W-SEC-K:1)
                   TO W-TOKEN(W-SEC-J:1)
                 MOVE C-HEX(FUNCTION MOD(W-SEC-BYTE-NUM, 16) + 1:1)
                   TO W-TOKEN(W-SEC-J + 1:1)
              END-PERFORM
           END-IF
           .
       R800-NEW-TOKEN-END.
           EXIT.

      *===============================================================*
      * R810-DERIVE: From W-TOKEN derive W-TOKENHASH, which is stored,*
      * and W-PHRASE, the one-time passphrase, which is never stored. *
      * The phrase alternates letters and digits, so it always meets  *
      * the default RACF passphrase rules.                            *
      *===============================================================*
       R810-DERIVE SECTION.
           SET FUNC-SHA256 TO TRUE
           MOVE 66 TO INPUT-LEN OF W-LCTFA991
           STRING 'H:' W-TOKEN DELIMITED BY SIZE
             INTO INPUT-DATA OF W-LCTFA991
           CALL W-A991-PGM USING W-LCTFA991

           IF A991-OK
              MOVE OUTPUT-DATA OF W-LCTFA991 TO W-TOKENHASH

              SET FUNC-SHA256 TO TRUE
              MOVE 66 TO INPUT-LEN OF W-LCTFA991
              STRING 'P:' W-TOKEN DELIMITED BY SIZE
                INTO INPUT-DATA OF W-LCTFA991
              CALL W-A991-PGM USING W-LCTFA991
           END-IF

           IF A991-OK
              PERFORM VARYING W-SEC-I FROM 1 BY 1 UNTIL W-SEC-I > 32
                 MOVE OUTPUT-DATA OF W-LCTFA991(W-SEC-I:1) TO W-SEC-BYTE
                 IF FUNCTION MOD(W-SEC-I, 2) = 1
                    MOVE C-LETTERS(FUNCTION MOD(W-SEC-BYTE-NUM, 26)
                                   + 1:1)
                      TO W-PHRASE(W-SEC-I:1)
                 ELSE
                    MOVE C-DIGITS(FUNCTION MOD(W-SEC-BYTE-NUM, 10)
                                  + 1:1)
                      TO W-PHRASE(W-SEC-I:1)
                 END-IF
              END-PERFORM
           END-IF
           .
       R810-DERIVE-END.
           EXIT.
