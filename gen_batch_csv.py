import csv

# 假设 fieldnames 和 rows 已经定义
fieldnames = ["Timestamp", "TraceId", "SpanId", "TraceFlags", "SeverityText", "SeverityNumber", "Name", "Body", "ResourceAttributes", "ScopeSchemaUrl", "ScopeName", "ScopeVersion", "ScopeAttributes", "LogAttributes"]
rows = []

# 生成示例数据
for i in range(1000):
    row = {
        "Timestamp": "now()",
        "TraceId": "generateUUIDv4()",
        "SpanId": "generateUUIDv4()",
        "TraceFlags": 0,
        "SeverityText": "INFO",
        "SeverityNumber": 1,
        "Name": "test_name",
        "Body": "test_body",
        "ResourceAttributes": "{}",
        "ScopeSchemaUrl": "http://example.com",
        "ScopeName": "scopeA",
        "ScopeVersion": "v1",
        "ScopeAttributes": "{}",
        "LogAttributes": "{}"
    }
    rows.append(row)

# 生成SQL文件
with open('data.sql', 'w') as sqlfile:
    sqlfile.write("INSERT INTO default.otel_logs_distributed (Timestamp, TraceId, SpanId, TraceFlags, SeverityText, SeverityNumber, Name, Body, ResourceAttributes, ScopeSchemaUrl, ScopeName, ScopeVersion, ScopeAttributes, LogAttributes) VALUES\n")
    for i, row in enumerate(rows):
        values = f"({row['Timestamp']}, '{row['TraceId']}', '{row['SpanId']}', {row['TraceFlags']}, '{row['SeverityText']}', {row['SeverityNumber']}, '{row['Name']}', '{row['Body']}', '{row['ResourceAttributes']}', '{row['ScopeSchemaUrl']}', '{row['ScopeName']}', '{row['ScopeVersion']}', '{row['ScopeAttributes']}', '{row['LogAttributes']}')"
        if i < len(rows) - 1:
            values += ",\n"
        else:
            values += ";"
        sqlfile.write(values)

print("SQL file 'data.sql' generated with 1000 rows.")