CREATE TABLE customer ON CLUSTER mycluster
(
    C_CUSTKEY       UInt32,
    C_NAME          String,
    C_ADDRESS       String,
    C_CITY          LowCardinality(String),
    C_NATION        LowCardinality(String),
    C_REGION        LowCardinality(String),
    C_PHONE         String,
    C_MKTSEGMENT    LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/customer', '{replica}')
ORDER BY (C_CUSTKEY);

CREATE TABLE customer_distributed ON CLUSTER mycluster
AS customer
ENGINE = Distributed(
    mycluster,
    default,
    customer,
    cityHash64(C_CUSTKEY)
);

CREATE TABLE lineorder ON CLUSTER mycluster
(
    LO_ORDERKEY             UInt32,
    LO_LINENUMBER           UInt8,
    LO_CUSTKEY              UInt32,
    LO_PARTKEY              UInt32,
    LO_SUPPKEY              UInt32,
    LO_ORDERDATE            Date,
    LO_ORDERPRIORITY        LowCardinality(String),
    LO_SHIPPRIORITY         UInt8,
    LO_QUANTITY             UInt8,
    LO_EXTENDEDPRICE        UInt32,
    LO_ORDTOTALPRICE        UInt32,
    LO_DISCOUNT             UInt8,
    LO_REVENUE              UInt32,
    LO_SUPPLYCOST           UInt32,
    LO_TAX                  UInt8,
    LO_COMMITDATE           Date,
    LO_SHIPMODE             LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/lineorder', '{replica}')
PARTITION BY toYear(LO_ORDERDATE)
ORDER BY (LO_ORDERDATE, LO_ORDERKEY);

CREATE TABLE lineorder_distributed ON CLUSTER mycluster
AS lineorder
ENGINE = Distributed(
    mycluster,
    default,
    lineorder,
    cityHash64(LO_ORDERKEY)
);

CREATE TABLE part ON CLUSTER mycluster
(
    P_PARTKEY       UInt32,
    P_NAME          String,
    P_MFGR          LowCardinality(String),
    P_CATEGORY      LowCardinality(String),
    P_BRAND         LowCardinality(String),
    P_COLOR         LowCardinality(String),
    P_TYPE          LowCardinality(String),
    P_SIZE          UInt8,
    P_CONTAINER     LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/part', '{replica}')
ORDER BY P_PARTKEY;

CREATE TABLE part_distributed ON CLUSTER mycluster
AS part
ENGINE = Distributed(
    mycluster,
    default,
    part,
    cityHash64(P_PARTKEY)
);

CREATE TABLE supplier ON CLUSTER mycluster
(
    S_SUPPKEY       UInt32,
    S_NAME          String,
    S_ADDRESS       String,
    S_CITY          LowCardinality(String),
    S_NATION        LowCardinality(String),
    S_REGION        LowCardinality(String),
    S_PHONE         String
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/supplier', '{replica}')
ORDER BY S_SUPPKEY;

CREATE TABLE supplier_distributed ON CLUSTER mycluster
AS supplier
ENGINE = Distributed(
    mycluster,
    default,
    supplier,
    cityHash64(S_SUPPKEY)
);

SET max_memory_usage = 20000000000;

CREATE TABLE lineorder_flat ON CLUSTER mycluster
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/lineorder_flat1', '{replica}')
ORDER BY (LO_ORDERDATE, LO_ORDERKEY)
AS SELECT
    l.LO_ORDERKEY AS LO_ORDERKEY,
    l.LO_LINENUMBER AS LO_LINENUMBER,
    l.LO_CUSTKEY AS LO_CUSTKEY,
    l.LO_PARTKEY AS LO_PARTKEY,
    l.LO_SUPPKEY AS LO_SUPPKEY,
    l.LO_ORDERDATE AS LO_ORDERDATE,
    l.LO_ORDERPRIORITY AS LO_ORDERPRIORITY,
    l.LO_SHIPPRIORITY AS LO_SHIPPRIORITY,
    l.LO_QUANTITY AS LO_QUANTITY,
    l.LO_EXTENDEDPRICE AS LO_EXTENDEDPRICE,
    l.LO_ORDTOTALPRICE AS LO_ORDTOTALPRICE,
    l.LO_DISCOUNT AS LO_DISCOUNT,
    l.LO_REVENUE AS LO_REVENUE,
    l.LO_SUPPLYCOST AS LO_SUPPLYCOST,
    l.LO_TAX AS LO_TAX,
    l.LO_COMMITDATE AS LO_COMMITDATE,
    l.LO_SHIPMODE AS LO_SHIPMODE,
    c.C_NAME AS C_NAME,
    c.C_ADDRESS AS C_ADDRESS,
    c.C_CITY AS C_CITY,
    c.C_NATION AS C_NATION,
    c.C_REGION AS C_REGION,
    c.C_PHONE AS C_PHONE,
    c.C_MKTSEGMENT AS C_MKTSEGMENT,
    s.S_NAME AS S_NAME,
    s.S_ADDRESS AS S_ADDRESS,
    s.S_CITY AS S_CITY,
    s.S_NATION AS S_NATION,
    s.S_REGION AS S_REGION,
    s.S_PHONE AS S_PHONE,
    p.P_NAME AS P_NAME,
    p.P_MFGR AS P_MFGR,
    p.P_CATEGORY AS P_CATEGORY,
    p.P_BRAND AS P_BRAND,
    p.P_COLOR AS P_COLOR,
    p.P_TYPE AS P_TYPE,
    p.P_SIZE AS P_SIZE,
    p.P_CONTAINER AS P_CONTAINER
FROM lineorder AS l
INNER JOIN customer AS c ON c.C_CUSTKEY = l.LO_CUSTKEY
INNER JOIN supplier AS s ON s.S_SUPPKEY = l.LO_SUPPKEY
INNER JOIN part AS p ON p.P_PARTKEY = l.LO_PARTKEY;


CREATE TABLE lineorder_flat_distributed ON CLUSTER mycluster
AS lineorder_flat
ENGINE = Distributed(
    mycluster,
    default,
    lineorder_flat,
    cityHash64(LO_ORDERKEY)
);
