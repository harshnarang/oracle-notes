-- rac_db_blocking_kill.sql
--
-- Who is blocking whom across every instance, with the kill statement for
-- the blocker built ready to paste. No statement text, for a fast look at a
-- terminal. Use rac_db_locks_with_sqls_kill.sql when the SQL is needed.
--
-- Run as: any user with SELECT_CATALOG_ROLE. Running the generated kill
--         additionally needs ALTER SYSTEM.
-- Usage:  @rac_db_blocking_kill
--
-- blocked_cnt is how many sessions that blocker is holding up. The sort puts
-- the worst offender at the top.
--
-- kill_script is a string. This script executes nothing. Read the row, then
-- paste the statement yourself if you want it.
--
-- Caution: the generated statement kills the session and rolls back its
-- transaction. IMMEDIATE returns control to you at once, it does not release
-- the locks at once, because the rollback still has to finish.
--
-- An empty kill_script means the blocker is a background process rather than
-- a user session, and killing is not the answer there.
--
-- Direct pairs only. A chain three deep reports as two unrelated rows.
-- gv$session.final_blocking_session resolves chains from 11.2.
--
-- gv$lock.block is reported as 2 on RAC for a global lock whose blocking
-- status is not known, so block > 0 returns those alongside confirmed
-- blockers.

SET LINESIZE 300
SET PAGESIZE 200
SET TRIMSPOOL ON

COLUMN blocked_cnt      FORMAT 999
COLUMN blocking_session FORMAT A95
COLUMN blocked_session  FORMAT A95
COLUMN kill_script      FORMAT A60

WITH pairs AS (
    SELECT DISTINCT
        s1.inst_id                            AS blocking_inst_id,
        s1.sid                                AS blocking_sid,
        s1.username || '@' || s1.machine
            || ' (INST='    || s1.inst_id
            || ' SID='      || s1.sid
            || ' ET='       || s1.last_call_et
            || ' STATUS='   || s1.status
            || ' EVENT='    || s1.event
            || ' MODULE='   || s1.module
            || ' ACTION='   || s1.action
            || ' PROGRAM='  || s1.program || ')' AS blocking_session,
        s2.username || '@' || s2.machine
            || ' (INST='    || s2.inst_id
            || ' SID='      || s2.sid
            || ' ET='       || s2.last_call_et
            || ' STATUS='   || s2.status
            || ' EVENT='    || s2.event
            || ' MODULE='   || s2.module
            || ' ACTION='   || s2.action
            || ' PROGRAM='  || s2.program || ')' AS blocked_session,
        CASE s1.type
            WHEN 'USER'
            THEN 'alter system kill session '''
                 || s1.sid || ',' || s1.serial# || ',@' || s1.inst_id
                 || ''' immediate;'
        END                                   AS kill_script
    FROM
        gv$lock l1
    JOIN
        gv$session s1
        ON  s1.inst_id = l1.inst_id
        AND s1.sid     = l1.sid
    JOIN
        gv$lock l2
        ON  l2.type = l1.type
        AND l2.id1  = l1.id1
        AND l2.id2  = l1.id2
    JOIN
        gv$session s2
        ON  s2.inst_id = l2.inst_id
        AND s2.sid     = l2.sid
    WHERE
        l1.block   > 0
    AND l2.request > 0
    AND NOT (s1.inst_id = s2.inst_id AND s1.sid = s2.sid)
)
SELECT
    COUNT(*) OVER (PARTITION BY blocking_inst_id, blocking_sid) AS blocked_cnt,
    blocking_session,
    blocked_session,
    kill_script
FROM
    pairs
ORDER BY
    blocked_cnt DESC,
    blocking_inst_id,
    blocking_sid;
