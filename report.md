# Clickhouse vs. Doris性能测试报告
## 环境准备
### clickhouse
| 节点 |  分片编号 | 副本编号 | CPU核数| 内存|
|------|----------|----------|---|---|
| ck-0-0 |  1        | 1        |6|8|
| ck-1-0 |  2        | 1        |6|8|

### Doris集群
| 节点 |  角色 | CPU核数| 内存|
|------|----------|---|---|
| fe-0 |  FE      |4|12|
| be-0 |  BE      |8|16|

## 写入性能测试
由于写入性能与表结构，索引设置等密切相关， 本测试以实际的`opentelemetry collector`向后端写入的表结构及配置为基准

### clickhouse
#### 创建log表(cluster)
```sql
CREATE TABLE default.otel_logs ON CLUSTER mycluster (
    `Timestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `TimestampTime` DateTime DEFAULT toDateTime(Timestamp),
    `TraceId` String CODEC(ZSTD(1)),
    ...
    ...
    ...


CREATE TABLE default.otel_logs_distributed ON CLUSTER mycluster
AS default.otel_logs
ENGINE = Distributed(
    mycluster,             
    default,                
    otel_logs,              
    cityHash64(Body)     
);
```
由于是需要测试clickhouse集群模式的性能， 因此要创建集群类型的本地表（`otel_logs`），同时创建相应的分布式表（`otel_logs_distributed`）, 后续的读写操作均基于分布式表进行， 由clickhouse自动对请求分发到不同节点执行。

#### 性能测试
为了模拟多并发，采用多进程的方式编写python脚本， 构造一些log数据，插入到`otel_logs_distributed`表中。 在集群配置固定的情况下， 写入性能可能受以下2个写入参数的影响：
1. 并发数
2. 每次写入操作的数据条数(以下称`batch size`)

我们采用固定变量法分别测试两个参数对写入速度的影响，写入数据的总条数为`100w`条,先测试并发数的影响, 结果如下：

| 并发数 | batch size| time(s)  | rows/s  |
|--------|-------|-------|---------|
| 1      | 1000  | 51.19 | 19534   |
| 2      | 1000  | 22.29 | 44869   |
| 5      | 1000  | 16.32 | 152204  |
| 10     | 1000  | 3.11  | 321517  |


接下来测试`batch size`对写入性能的影响， 结果如下：

| 并发数 | batch size | time(s) | rows/s  |
|--------|------------|---------|---------|
| 1      | 1000       | 51.19   | 19534   |
| 1      | 2000       | 34.57   | 28924   |
| 1      | 5000       | 26.06   | 38373   |
| 1      | 10000      | 22.61   | 44227   |

**结论 1**：在`batch size`固定的情况下， clickhouse的写入性能可随并发数量线性提升。

**结论 2**：在并发数固定的情况下， clickhouse的写入性能随`batch size`的提升有所提高， 但不能线性提升。

### Doris
#### 创建log表
```sql
CREATE TABLE IF NOT EXISTS otel_logs
(
    service_name          VARCHAR(200),
    timestamp             DATETIME(6),
    trace_id              VARCHAR(200),
    span_id               STRING,
    severity_number       INT,
    severity_text         STRING,
    body                  STRING,
    resource_attributes   JSON,
    log_attributes        JSON,
    scope_name            STRING,
    scope_version         STRING,
    INDEX idx_service_name(service_name) USING INVERTED,
    INDEX idx_timestamp(timestamp) USING INVERTED,
    INDEX idx_trace_id(trace_id) USING INVERTED,
    INDEX idx_span_id(span_id) USING INVERTED,
    INDEX idx_severity_number(severity_number) USING INVERTED,
    INDEX idx_body(body) USING INVERTED PROPERTIES("parser"="unicode", "support_phrase"="true"),
    INDEX idx_severity_text(severity_text) USING INVERTED,
    INDEX idx_scope_name(scope_name) USING INVERTED,
    INDEX idx_scope_version(scope_version) USING INVERTED
)
ENGINE = OLAP
DUPLICATE KEY(service_name, timestamp)
PARTITION BY RANGE(timestamp) (
    PARTITION p2024 VALUES LESS THAN ("2025-01-01")
)
DISTRIBUTED BY HASH(trace_id) BUCKETS 1
PROPERTIES (
    "replication_num" = "1"
);
```
与clickhouse一样， 采用单副本的模式创建表，并在`body`等多个字段上创建了倒排索引， 以测试全文搜索的性能。

#### 性能测试
与clickhouse类型，使用python的多进程编程，利用多核进行并发写入， 同样采用控制变量法观察并发数与`batch size`对写入性能的影响。 测试写入数据总量也是`100w`条。

## 并发数测试结果

首先观察`batch size`固定的情况下， 并发数对写入性能的影响：
| 并发数 | batch size | time(s) | rows/s  |
|--------|------------|---------|---------|
| 1      | 1000       | 557.89  | 1792    |
| 5      | 1000       | 147.62  | 6774    |
| 10     | 1000       | 78.72   | 12703   |

再观察在并发数相同的情况下， `batch size`对写入性能的影响：
| 并发数 | batch size | time(s) | rows/s  |
|--------|------------|---------|---------|
| 10     | 1000       | 78.72   | 12703   |
| 10     | 2000       | 49.86   | 20054   |
| 10     | 5000       | 48.98   | 20416   |
| 10     | 10000       | 55.41   | 18047   |

**结论 1**: 增大并发数可线性提高写入性能.

**结论 2**：在`batch size < 2000`范围内增大batch size可较大提高写入性能，再增大`batch size`对写入性能提高有限。

## 查询性能测试
Star Schema Benchmark(SSB) 是一个轻量级的数仓场景下的性能测试集。SSB 基于 TPC-H 提供了一个简化版的星型模型数据集，主要用于测试在星型模型下，多表关联查询的性能表现。另外，业界内通常也会将 SSB 打平为宽表模型（以下简称：SSB flat），来测试查询引擎的性能.

测试数据集的规模在600,000,000条左右。

### Clickhouse vs. Doris 测试结果
| 查询类型 | Query | ClickHouse (s) | Doris (s) |
|-----------|-------|---------------|-----------|
| 基本过滤查询和聚合操作（Q1 类查询） | q1.1  | 0.103         | 0.36      |
|           | q1.2  | 0.045         | 0.09      |
|           | q1.3  | 0.041         | 0.24      |
| 维度过滤和多表 JOIN（Q2 类查询）  | q2.1  | 0.142         | 2.5       |
|           | q2.2  | 0.141         | 1.11      |
|           | q2.3  | 0.17          | 1.02      |
| 分组、排序和复杂聚合（Q3 类查询） | q3.1  | 0.183         | 2.0       |
|           | q3.2  | 0.175         | 1.51      |
|           | q3.3  | 0.111         | 0.74      |
|           | q3.4  | 0.053         | 0.08      |
| 窄范围查询（Q4 类查询）          | q4.1  | 0.252         | 2.29      |
|           | q4.2  | 0.103         | 0.57      |
|           | q4.3  | 0.082         | 0.31      |

### 全文搜素性能对比
在向clickhouse和Doris插入构造数据时， 以`0.0001`的概率插入了带有关键词`Thoughtworks`的日志数据，以此查询来比较两者的全文搜索性能, 全文搜索的数据总量在20,000,000条左右, 其中约万分之一的数据符合查询条件：

#### Clickhouse
```sql
SELECT count(*)
FROM otel_logs_distributed

Query id: 77e9d426-77da-457a-abbf-4485217c4691

   ┌──count()─┐
1. │ 23911959 │ -- 23.91 million
   └──────────┘

1 row in set. Elapsed: 0.011 sec.

SELECT *
FROM default.otel_logs_distributed
WHERE Body LIKE '%ThoughtWorks%';

↖ Progress: 21.89 million rows, 2.93 GB (29.77 million rows/s., 3.98 GB/s.↑ Progress: 24.39 million rows, 3.25 GB (31.36 million rows/s., 4.18 GB/s.↗ Progress: 24.39 million rows, 3.25 GB (31.36 million rows/s., 4.18 GB/s.

2375 rows in set. Elapsed: 0.778 sec. Processed 24.39 million rows, 3.25 GB (31.35 million rows/s., 4.18 GB/s.)
Peak memory usage: 24.95 MiB.
```
整理上述测试数据：
| 数据总量 | 耗时(s) | 扫描速度(rows/s) | 内存峰值 |
|-----------|-------|---------------|-----------|
|23.91 million| 0.778| 31.35 million|24.95M|

#### Doris
Doris的log表中在`body`字段上设置了倒排索引， 因此可以用`MATCH`语法进行全文搜索：
```sql
select count(*) from otel_logs;
+----------+
| count(*) |
+----------+
| 23000000 |
+----------+
1 row in set (0.11 sec)

SELECT * FROM otel_logs WHERE body MATCH_ANY 'ThoughtWorks';
...
...
2200 rows in set (0.10 sec)

在与clickhouse数据量相当的情况下， doris全文查询符合条件的数据用时`0.1s`.
```

## 结果分析
从上述测试结果来看：
+ 写入性能： clickhouse每秒处理数据量明显优于Doris。
+ SSB宽表查询性能: clickhouse在4类查询上的表现都明显优于Doris。
+ 全文查询: 数据量相当的情况下， Doris的表现明显优于Clickhouse。

从上述结果看， clickhouse在数据写入和宽表查询方面要远远优于Doris，但这不能完全说明问题，clickhouse基于单节点和集群设计都有较高的基准表现， 而本测试中Doris集群的配置仅仅达到了可运行的最低要求， Doris本身是基于大集群模式的设计， 其性能应在多FE,BE架构下才能得到充分的发挥。

另外，Doris在前两项表现均不如clickhouse的情况下， 其全表查询的表现竟然反过来远超clickhouse， 这应该得益于clickhouse没有的倒排索引，由此可见，在Doris集群资源充足的场景下，其在全文搜索方面的性能应该会更加优异，非常适合用作日志引擎。