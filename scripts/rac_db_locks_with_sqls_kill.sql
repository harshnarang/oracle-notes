-- rac_db_locks_with_sqls_kill.sql
--
-- rac_db_blocking_kill.sql with the statement text added. Same query, same
-- caveats, read that header rather than have them repeated here.
--
-- blocking_sql comes from prev_sql_id where the blocker has gone idle, which
-- is the usual case, since it took the lock and then stopped running. Both
-- SQL columns are cut to 80 characters or the report is unreadable.
--
-- In a CDB the same sql_id can exist in more than one container, so a pair
-- can report more than once. Add a con_id predicate to the gv$sqlarea joins
-- if that happens.

SET LINESIZE 420
SET PAGESIZE 200
SET TRIMSPOOL ON

COLUMN blocked_cnt      FORMAT 999
COLUMN blocking_session FORMAT A90
COLUMN blocked_session  FORMAT A90
COLUMN kill_script      FORMAT A60
COLUMN blocking_sql     FORMAT A80
COLUMN blocked_sql      FORMAT A80

WITH pairs AS (
    SELECT DISTINCT
        s1.inst_id                            AS blocking_inst_id,
        s1.sid                                AS blocking_sid,
        s2.inst_id                            AS blocked_inst_id,
        COALESCE(s1.sql_id, s1.prev_sql_id)   AS blocking_sql_id,
        s2.sql_id                             AS blocked_sql_id,
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
    COUNT(*) OVER (PARTITION BY p.blocking_inst_id, p.blocking_sid) AS blocked_cnt,
    p.blocking_session,
    p.blocked_session,
    p.kill_script,
    SUBSTR(bg.sql_text, 1, 80)                                      AS blocking_sql,
    SUBSTR(bd.sql_text, 1, 80)                                      AS blocked_sql
FROM
    pairs p
LEFT JOIN
    gv$sqlarea bg
    ON  bg.sql_id  = p.blocking_sql_id
    AND bg.inst_id = p.blocking_inst_id
LEFT JOIN
    gv$sqlarea bd
    ON  bd.sql_id  = p.blocked_sql_id
    AND bd.inst_id = p.blocked_inst_id
ORDER BY
    blocked_cnt DESC,
    p.blocking_inst_id,
    p.blocking_sid;
