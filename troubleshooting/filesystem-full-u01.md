# Filesystem full on /u01 (Grid Infrastructure ADR logs)

**Applies to:** Oracle RAC and Oracle Database Appliance, 11g to 23ai

## Symptom

`/u01` reaches close to 100 percent. The databases and the cluster keep running normally, because the space is not being consumed by the databases. It is consumed under the Grid Infrastructure diagnostic directory, and in most cases the bulk of it is listener logging.

## Cause

The Automatic Diagnostic Repository keeps trace and alert data with a long default retention, 30 days for trace and 365 days for alert. On a busy cluster the listener alert and trace directories grow to many gigabytes and are never purged automatically at that rate. The Grid software home and the patch storage also sit on `/u01`, but those are fixed in size and must not be touched.

## Check

Which mount and how full:

```bash
df -h /u01
```

Biggest directories on the filesystem. `-x` keeps the scan on `/u01` and does not cross into other mounts:

```bash
du -xh /u01 2>/dev/null | grep -E '^[0-9.]+G' | sort -rh | head -30
```

The bulk is normally under `/u01/app/grid/diag/tnslsnr/<node>` for the listeners and `/u01/app/grid/diag/crs/<node>/crs/trace` for Clusterware.

List the ADR homes on the node you are on:

```bash
adrci exec="show homes"
```

Retention policy for a home. Look at `SHORTP_POLICY`, which covers trace in hours, and `LONGP_POLICY`, which covers alert in hours. Defaults are 720 and 8760:

```bash
adrci exec="set homepath diag/tnslsnr/$(hostname -s)/listener; show control"
```

How much space the purge will return, measured as the files older than 3 days:

```bash
find /u01/app/grid/diag/tnslsnr/$(hostname -s) -type f -mtime +3 -exec du -ch {} + | tail -1
```

Whether it is many old files or one giant file. A single very large `log.xml` points at abnormal listener volume rather than normal history:

```bash
find /u01/app/grid/diag/tnslsnr/$(hostname -s) -type f -exec ls -lhS {} + 2>/dev/null | head -15
```

## Fix

Purge ADR by age with `adrci`, not with `rm`. Removing ADR files directly leaves the repository metadata inconsistent. This loop finds the local listener and CRS homes and purges anything older than 3 days. Run it on each node:

```bash
for H in $(adrci exec="show homes" | grep -E 'tnslsnr|/crs$'); do
  adrci exec="set homepath $H; purge -age 4320 -type ALERT; purge -age 4320 -type TRACE; purge -age 4320 -type INCIDENT; purge -age 4320 -type CDUMP"
done
```

`4320` is minutes, which is 3 days.

Confirm the space came back:

```bash
df -h /u01
```

Cluster Verification Utility reports under `crsdata` are also safe to trim:

```bash
find /u01/app/grid/crsdata/@global/cvu/report -type f -mtime +14 -delete
```

## Prevent

Shorten the ADR retention per home so it self purges from now on. Run on each node:

```bash
for H in $(adrci exec="show homes" | grep -E 'tnslsnr|/crs$'); do
  adrci exec="set homepath $H; set control (SHORTP_POLICY = 168, LONGP_POLICY = 336)"
done
```

`168` hours keeps 7 days of trace, `336` hours keeps 14 days of alert, which is enough for a listener.

If the listener logs grow back quickly even after this, listener tracing may have been left on. Check it as the Grid owner, so `ORACLE_HOME` points at the Grid home:

```bash
grep -i trace_level $ORACLE_HOME/network/admin/listener.ora 2>/dev/null
```

A level other than `off` or `0` makes the listener log grow fast and is the real cause. Turn it off unless a trace is actively needed.

Purge the database ADR homes the same way, using their homes `diag/rdbms/<db>/<instance>`. Audit files are separate from ADR and are a common second cause of a full `/u01`, so clear the old ones too:

```bash
find /u01/app/*/oracle/admin/*/adump -name "*.aud" -mtime +30 -delete
```

## Worked example

A 2-node cluster, `/u01` sized 40G on each node, both nodes near full.

Before, node 1:

```
/u01   40G   37G used   901M free   98%
```

The GB scan showed the bulk under the listener ADR: about 15G in `diag/tnslsnr/<node>`, across the listener, SCAN listener, and ASM listener alert and trace directories, plus about 4G in `diag/crs/<node>/crs/trace`. The database directories were not the problem.

Measuring only the files older than 3 days confirmed how much the purge would return:

```
listener   about 13G
crs trace  about 1G
```

After the `purge -age 4320` loop across the listener and CRS homes:

```
node 1   29G used   8.5G free   78%
node 2   27G used   11G free    71%
```

Roughly 8G reclaimed per node, all of it old listener and Clusterware logs, with no impact to the databases or the cluster. The retention change then stopped it returning.

## Do not touch

- The Grid software home, `/u01/app/<version>/grid`. Deleting anything here breaks Grid Infrastructure.
- `.patch_storage` under the Grid home. It is needed to roll back patches.
- The ASM diskgroups. They are not on `/u01`.
- Archived redo logs. Never `rm` them to free space. Back them up with RMAN and let RMAN delete them, or recovery will fail.

## Version notes

- 12.2 onwards, Grid and Clusterware logs are in ADR under the Grid base `diag` directory. Earlier releases use `$GRID_HOME/log/<node>`.
- On Oracle Database Appliance the same layout applies, with the Grid base typically under `/u01/app/grid`.
