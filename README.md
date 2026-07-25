# Oracle Notes

Notes on Oracle database errors: cause, checks, fix, prevention.

Baseline is 19c. Queries use `GV$` views so they run unchanged on single instance and RAC. RAC-specific behaviour is noted inline.

## Troubleshooting

| Error | Description |
|---|---|
| [ORA-00257](troubleshooting/ORA-00257.md) | Archiver error, connect internal only until freed |
| [ORA-00060](troubleshooting/ORA-00060.md) | Deadlock detected while waiting for resource |
| [ORA-01555](troubleshooting/ORA-01555.md) | Snapshot too old |
| [ORA-01578](troubleshooting/ORA-01578.md) | Data block corrupted |
| [ORA-01652](troubleshooting/ORA-01652.md) | Unable to extend temp segment |
| [ORA-04031](troubleshooting/ORA-04031.md) | Unable to allocate shared memory |
| [ORA-12541](troubleshooting/ORA-12541.md) | TNS: no listener |
| [ORA-29740](troubleshooting/ORA-29740.md) | Instance eviction (node eviction) |

## Operations

| Topic | Description |
|---|---|
| [Filesystem full on /u01](troubleshooting/filesystem-full-u01.md) | Grid Infrastructure ADR logs filling the mount, safe cleanup with adrci |

## Conventions

- One error per file, filename is the error code
- `GV$` views throughout, `INST_ID` in the output
- SQL prompts for values with substitution variables where input is needed
- Statements that roll back work, hold locks, or require a restart are marked `Caution`
- Sizing and parameter values are illustrative. Read the current setting and size to the instance rather than copying the number
