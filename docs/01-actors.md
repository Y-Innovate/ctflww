# Actors

Who and what interacts with the CTF application, how each is identified, and
what each may do. Use case IDs refer to [02-use-cases.md](02-use-cases.md).

## People

| Actor | Identified by | Goal | Use cases |
|---|---|---|---|
| Visitor | Nobody: anonymous | See which events exist and how they are going | V1, V2 |
| Registrant | Event registration code, then a one-time claim token | Get an account and into an event | R1-R3 |
| Player | RACF userid + password | Compete in an event | P1-P9 |
| Team captain | A player who created or was handed a team | Keep the team in order | T4, plus all player use cases |
| Admin / organizer | Entra ID, mapped to a RACF userid | Run events, look after players, keep the game fair | A1, A3-A9 |
| Challenge author | Entra ID, mapped to a RACF userid | Build the reusable challenge library | A2, A3 |

Notes:

- **A Visitor, a Registrant and a Player can be the same person** at different
  moments. A Registrant becomes a Player when the password is chosen (R3).
- **Team captain is not a separate account type.** It is a relationship between
  a player and a team in one event.
- **Admin and challenge author are one role in v1.** They are listed apart so
  that a separate author role can be added later without changing the use cases.
- **Admins do not play.** An admin has no player record, so the player use cases
  are not available to them. Someone who wants to do both needs a player account
  too, and should not administer that event.

## Systems

| Actor | Role | Use cases |
|---|---|---|
| CTF backend (CICS) | Submits provisioning jobs and notices when they fail | S1, S3, S4 |
| Provisioning job (z/OS batch) | Runs the RACF commands and writes the result to DB2 | S2 |
| RACF | Holds player and admin userids; checks passwords | Used by P1, P3, R3 |
| Entra ID | Signs admins in | Used by A1-A9 |
| LWW gateway | Serves the web UI; signs players in (RACF) and admins in (Entra); holds the session, so the browser only gets a cookie; maps JSON to copybooks | All browser and API calls |

## What each actor can do

| Capability | Visitor | Registrant | Player | Captain | Admin/Author |
|---|---|---|---|---|---|
| See published events and leaderboards (frozen view) | Yes | Yes | Yes | Yes | Yes |
| See the live leaderboard during a freeze | - | - | - | - | Yes |
| Register with an event code | Yes | Yes | - | - | - |
| Join another event with its code | - | - | Yes | Yes | - |
| See challenges, submit flags, unlock hints | - | - | Joined events | Joined events | - |
| See announcements | - | - | Joined events | Joined events | Yes |
| Create or join a team | - | - | Yes | Yes | - |
| Remove a member, hand over captaincy | - | - | - | Own team | - |
| See event registration codes | - | - | - | - | Yes |
| See flags | - | - | - | - | Yes |
| Maintain events, challenges, awards, players | - | - | - | - | Yes |

## How identity reaches the backend

| Actor | Route | Userid CICS runs under |
|---|---|---|
| Visitor, Registrant | Browser -> LWW, no session | The CICS default userid |
| Player | Browser -> LWW, with the session from LWW's sign-in page (RACF userid and passphrase) | The player's generated RACF userid |
| Admin | Browser -> LWW, with the session from LWW's Entra redirect | The RACF userid mapped from Entra |
| Job submission task | Started by `CTFC303`, checks the claim token | A submit userid; only this one has surrogate access to the batch userid |
| Provisioning job | JES | A batch userid with group-special |

The backend always takes the player from the CICS userid, never from the request.

## Player account lifecycle

```
             job ok             password chosen
 PENDING ------------> READY --------------------> ACTIVE <-----+
    |                    |                          |  |        |
    | job failed         | not claimed in time      |  | admin  | admin
    v                    v                          |  v        | resume
 FAILED               REVOKED <---------------------+ REVOKED --+
                         |
                         v
                      DELETED
```

- `READY` also applies after an admin password reset: the player goes back
  through R3.
- `DELETED` means the RACF userid is gone. The DB2 row stays, so past
  leaderboards keep their names.
