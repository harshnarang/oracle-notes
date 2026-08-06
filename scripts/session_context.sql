-- session_context.sql
--
-- Where am I, and switching current_schema.
--
-- current_schema changes name resolution only. Privileges stay with
-- SESSION_USER, so getting back is the same statement with your own name.

SET LINESIZE 200
SET PAGESIZE 100

COLUMN name  FORMAT A18
COLUMN value FORMAT A40


-- ============================================================================
-- 1. Everything about this session in one list.
-- ============================================================================

SELECT 1 AS seq, 'session_user'   AS name, SYS_CONTEXT('USERENV', 'SESSION_USER')   AS value FROM dual UNION ALL
SELECT 2,        'current_schema',         SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')       FROM dual UNION ALL
SELECT 3,        'instance_name',          SYS_CONTEXT('USERENV', 'INSTANCE_NAME')        FROM dual UNION ALL
SELECT 4,        'db_name',                SYS_CONTEXT('USERENV', 'DB_NAME')              FROM dual UNION ALL
SELECT 5,        'con_name',               SYS_CONTEXT('USERENV', 'CON_NAME')             FROM dual UNION ALL
SELECT 6,        'service_name',           SYS_CONTEXT('USERENV', 'SERVICE_NAME')         FROM dual UNION ALL
SELECT 7,        'sid',                    SYS_CONTEXT('USERENV', 'SID')                  FROM dual
ORDER BY 1;


-- ============================================================================
-- 2. Short form. Who you are, and what unqualified names resolve against.
-- ============================================================================

SELECT SYS_CONTEXT('USERENV', 'SESSION_USER')   AS session_user,
       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS current_schema
  FROM dual;


-- ============================================================================
-- 3. This session's identifiers, for a kill or a trace.
-- ============================================================================

SELECT s.inst_id,
       s.sid,
       s.serial#,
       p.spid,
       s.machine,
       s.program
  FROM gv$session s
  JOIN gv$process p
    ON  p.inst_id = s.inst_id
    AND p.addr    = s.paddr
 WHERE s.sid      = SYS_CONTEXT('USERENV', 'SID')
   AND s.inst_id  = SYS_CONTEXT('USERENV', 'INSTANCE')
 ORDER BY s.inst_id;


-- ============================================================================
-- 4. What the schema you are pointed at actually holds, by object type.
-- ============================================================================

SELECT object_type,
       COUNT(*) AS objects
  FROM all_objects
 WHERE owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
 GROUP BY object_type
 ORDER BY objects DESC;


-- ============================================================================
-- 5. Switch current_schema, then confirm it took.
-- ============================================================================

ALTER SESSION SET CURRENT_SCHEMA = &schema;

SELECT SYS_CONTEXT('USERENV', 'SESSION_USER')   AS session_user,
       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS current_schema
  FROM dual;
