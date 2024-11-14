#!/bin/bash

# install ck
kubectl apply -f https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/deploy/operator/clickhouse-operator-install-bundle.yaml

# 200,0000 records
# 单条插入， 200w条数据
time clickhouse-benchmark --concurrency 5 --iterations 2000000 --user default --password password --database default --query "INSERT INTO default.otel_logs_distributed (Timestamp, TraceId, SpanId, TraceFlags, SeverityText, SeverityNumber, ServiceName, Body, ResourceSchemaUrl, ResourceAttributes, ScopeSchemaUrl, ScopeName, ScopeVersion, ScopeAttributes, LogAttributes) VALUES (now(), concat('trace_', toString(rand() % 1000000)), concat('span_', toString(rand() % 1000000)), 0, 'INFO', 1, 'serviceA', 'test_body', 'http://example.com', '{}', 'http://example.com', 'scopeA', 'v1', '{}', '{}');" 

# 批量插入， 200w条数据
time clickhouse-benchmark --concurrency 5 --iterations 1000 --user default --password password --database default --query="