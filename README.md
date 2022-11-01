# ProxySQL Sharding Demos
A collection of demo use cases for sharding data with ProxySQL and MySQL.

Note that these demos are using MySQL 5.7 due to complexities with password hashing introduced in MySQL 8.

## Requirements
All demos require the following on your machine:

* [Docker][docker]
* [Docker Compose][docker-compose]
* [MySQL CLI client][mysql-client]

## Use Cases

* [Split Reads and Writes](#split-reads-and-writes)
* [Shard Schema](#shard-schema)
* [Shard Data](#shard-data)

### Split Reads and Writes
Uses a two node cluster to split reads and writes. Writes will go to the primary node while reads will go to the replica.

#### Usage
From the [`split-read-write`](./split-read-write) directory, start the containers:

```bash
$ docker-compose up -d
```

Note that the replica node (mysql_replica) is using a custom config file that sets the [read_only][mysql-read-only] value to 1.
This configures ProxySQL to treat it as a read replica.

Open a MySQL client session:

```
$ mysql -h127.0.0.1 -P16033 -uapp -p
```
> Default password is `foobar`

Open a ProxySQL admin session:
```bash
$ mysql -h127.0.0.1 -P16032 -upadmin -p --prompt "ProxySQL Admin>"
```
> Default password is `padmin`

In the admin session, get the list of MySQL servers like so:

```
ProxySQL Admin>SELECT * FROM mysql_servers;
+--------------+---------------+------+-----------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
| hostgroup_id | hostname      | port | gtid_port | status | weight | compression | max_connections | max_replication_lag | use_ssl | max_latency_ms | comment |
+--------------+---------------+------+-----------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
| 10           | mysql_primary | 3306 | 0         | ONLINE | 1      | 0           | 200             | 0                   | 0       | 0              |         |
| 20           | mysql_replica | 3306 | 0         | ONLINE | 1      | 0           | 200             | 0                   | 0       | 0              |         |
| 20           | mysql_primary | 3306 | 0         | ONLINE | 1      | 0           | 200             | 0                   | 0       | 0              |         |
+--------------+---------------+------+-----------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
```
The servers are split into two groups: 10 = primary and 20 = replicas.

You should see that the primary node exists in both group 10 and 20. While the replica node exists in group 20 only.

In the normal client session, run two queries; a read and a write:

```
mysql> SELECT * FROM machines;
+----+------------+---------+-----------+---------+
| id | customerid | name    | ip        | deleted |
+----+------------+---------+-----------+---------+
|  1 |          1 | dms-001 | 1.2.3.4   |       0 |
|  2 |          1 | dms-002 | 2.3.4.5   |       0 |
|  3 |          1 | dms-003 | 3.4.5.6   |       0 |
|  4 |          2 | sdg-001 | 6.7.8.9   |       0 |
|  5 |          2 | sdg-002 | 7.8.9.10  |       0 |
|  6 |          2 | sdg-003 | 8.9.10.11 |       0 |
+----+------------+---------+-----------+---------+
6 rows in set (0.01 sec)

mysql> UPDATE machines SET ip = '10.1.2.3.4' WHERE id = 1;
Query OK, 1 row affected (0.01 sec)
Rows matched: 1  Changed: 1  Warnings: 0
```
As far as the client is concerned, these queries worked as you'd expect. The data was read and written. But behind the scenes, ProxySQL has done the heavy lifting of directing these queries to the appropriate nodes.

To validate this, we can look at the [ProxySQL query digest][query-digest]. On the ProxySQL admin session run this query:

```
ProxySQL Admin>SELECT hostgroup, schemaname, username, digest_text FROM stats_mysql_query_digest;
+-----------+------------+----------+-----------------------------------------+
| hostgroup | schemaname | username | digest_text                             |
+-----------+------------+----------+-----------------------------------------+
| 10        | rwsplit    | app      | UPDATE machines SET ip = ? WHERE id = ? |
| 20        | rwsplit    | app      | SELECT * FROM machines                  |
| 10        | rwsplit    | app      | select @@version_comment limit ?        |
+-----------+------------+----------+-----------------------------------------+
```
What we see here is that the `SELECT` (a read) was handled by group 20 whereas the `UPDATE` (a write) was handled by group 10.

### Shard Schema
Uses a two node cluster to redirect queries to entirely different schemas, hosted on dedicated nodes. Two schemas have been created:

* `shared`
* `superdupergames`

This is simulating the idea that a specific customer may have their data moved to a specific set of MySQL node(s) for performance reasons.

#### Usage
From the [`schema-based`](./schema-based) directory, start the containers:

```bash
$ docker-compose up -d
```

Open a MySQL client session:

```
$ mysql -h127.0.0.1 -P16033 -uapp -p
```
> Default password is `foobar`

Open a ProxySQL admin session:
```bash
$ mysql -h127.0.0.1 -P16032 -upadmin -p --prompt "ProxySQL Admin>"
```
> Default password is `padmin`

In the admin session, get the list of MySQL servers like so:

```
ProxySQL Admin>SELECT * FROM mysql_servers;
+--------------+-------------+------+-----------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
| hostgroup_id | hostname    | port | gtid_port | status | weight | compression | max_connections | max_replication_lag | use_ssl | max_latency_ms | comment |
+--------------+-------------+------+-----------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
| 10           | mysql_node0 | 3306 | 0         | ONLINE | 1      | 0           | 200             | 0                   | 0       | 0              |         |
| 20           | mysql_node1 | 3306 | 0         | ONLINE | 1      | 0           | 200             | 0                   | 0       | 0              |         |
+--------------+-------------+------+-----------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
```
You should see two servers, one in each hostgroup (10 and 20). Rules have been configured to send queries for the `shared`

In the normal client session, run two queries; one against each schema:
```
mysql> SELECT * FROM shared.machines;
+----+------------+---------+-----------+---------+
| id | customerid | name    | ip        | deleted |
+----+------------+---------+-----------+---------+
|  1 |          1 | dms-001 | 1.2.3.4   |       0 |
|  2 |          1 | dms-002 | 2.3.4.5   |       0 |
|  3 |          1 | dms-003 | 3.4.5.6   |       0 |
|  4 |          2 | sdg-001 | 6.7.8.9   |       0 |
|  5 |          2 | sdg-002 | 7.8.9.10  |       0 |
|  6 |          2 | sdg-003 | 8.9.10.11 |       0 |
+----+------------+---------+-----------+---------+

mysql> use superdupergames;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> SELECT * FROM machines;
+----+------------+---------+-----------+---------+
| id | customerid | name    | ip        | deleted |
+----+------------+---------+-----------+---------+
|  1 |          1 | dms-001 | 1.2.3.4   |       0 |
|  2 |          1 | dms-002 | 2.3.4.5   |       0 |
|  3 |          1 | dms-003 | 3.4.5.6   |       0 |
|  4 |          2 | sdg-001 | 6.7.8.9   |       0 |
|  5 |          2 | sdg-002 | 7.8.9.10  |       0 |
|  6 |          2 | sdg-003 | 8.9.10.11 |       0 |
+----+------------+---------+-----------+---------+
6 rows in set (0.00 sec)
```
As far as the client is concerned, these queries worked as you'd expect. The data was read. But behind the scenes, ProxySQL has done the heavy lifting of directing these queries to the appropriate nodes.

To validate this, we can look at the [ProxySQL query digest][query-digest]. On the ProxySQL admin session run this query:
```
ProxySQL Admin>SELECT hostgroup, schemaname, username, digest_text FROM stats_mysql_query_digest;
+-----------+--------------------+----------+----------------------------------------+
| hostgroup | schemaname         | username | digest_text                            |
+-----------+--------------------+----------+----------------------------------------+
| 20        | superdupergames    | app      | SELECT * FROM machines                 |
| 20        | superdupergames    | app      | SELECT * FROM `machines` WHERE ?=?     |
| 20        | superdupergames    | app      | SELECT * FROM `customers` WHERE ?=?    |
| 20        | superdupergames    | app      | show databases                         |
| 10        | information_schema | app      | SELECT DATABASE()                      |
| 10        | information_schema | app      | SELECT * FROM superdupergames.machines |
| 20        | superdupergames    | app      | show tables                            |
| 10        | information_schema | app      | SELECT * FROM shared.machines          |
| 10        | information_schema | app      | select @@version_comment limit ?       |
+-----------+--------------------+----------+----------------------------------------+
```
What we see here is that the query against the `shared` schema was handled by host group 10 (node0) and the query against the `superdupergames` schema was handled by host group 20 (node1).

### Shard Data
Uses a three node cluster to redirect queries to appropriate nodes hosting a shard of a given set of data.

#### Usage
TBC

[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/
[mysql-client]: https://dev.mysql.com/doc/refman/5.7/en/document-store-shell-install.html
[mysql-read-only]: https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_read_only
[query-digest]: https://proxysql.com/documentation/stats-statistics/#stats_mysql_query_digest