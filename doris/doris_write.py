import random
import string
import time
import datetime
import json
import argparse
from mysql.connector import connect, Error
from concurrent.futures import ProcessPoolExecutor, as_completed

# Doris connection settings
def get_client():
    return connect(
        host='doriscluster-sample-fe-service.default',  # 替换为你的 Doris 服务
        port=9030,
        user='root',
        password='',
        database='otel'
    )

# Function to generate random log entry data
def generate_log_entry():
    random_message = ''.join(random.choices(string.ascii_letters + string.digits, k=10))
    if random.random() < 0.0001:  # 0.0001 的概率插入包含 "thoughtworks" 的日志记录
        body_text = f"Log entry for {random.choice(['John', 'Jane', 'Michael', 'Alice'])} from {random.choice(['New York', 'London', 'Sydney', 'Tokyo'])}, experiencing {random.choice(['sunny', 'rainy', 'cloudy', 'clear'])} weather. Random message: {random_message}. ThoughtWorks is mentioned here."
    else:
        body_text = f"Log entry for {random.choice(['John', 'Jane', 'Michael', 'Alice'])} from {random.choice(['New York', 'London', 'Sydney', 'Tokyo'])}, experiencing {random.choice(['sunny', 'rainy', 'cloudy', 'clear'])} weather. Random message: {random_message}"
    return (
        random.choice(['serviceA', 'serviceB', 'serviceC', 'serviceD']),  # service_name
        datetime.datetime.now(),  # timestamp
        f"trace_{random.randint(1000, 9999)}",  # trace_id
        f"span_{random.randint(10000, 99999)}",  # span_id
        random.randint(1, 4),  # severity_number
        random.choice(['INFO', 'WARN', 'ERROR', 'DEBUG']),  # severity_text
        body_text,  # body
        json.dumps({"key1": "value1", "key2": "value2"}),  # resource_attributes
        json.dumps({"keyA": "valueA", "keyB": "valueB"}),  # log_attributes
        f"scope{random.choice(['A', 'B', 'C', 'D'])}",  # scope_name
        'v1'  # scope_version
    )

# Function to perform insert into Doris
def insert_log_entries(values):
    client = get_client()
    cursor = client.cursor()
    query = """
    INSERT INTO otel_logs (
        service_name, timestamp, trace_id, span_id, severity_number, severity_text,
        body, resource_attributes, log_attributes, scope_name, scope_version
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(query, values)
    client.commit()
    cursor.close()
    client.close()

# Main function to perform load test with concurrency
def main(num_threads, total_entries, entries_per_batch):
    num_batches = total_entries // (num_threads * entries_per_batch)  # Number of batches per thread

    start_time = time.time()

    # Generate SQL data
    sql_data = []
    for _ in range(num_threads * num_batches):
        sql_data.append([generate_log_entry() for _ in range(entries_per_batch)])

    generation_end_time = time.time()

    # Insert data into Doris
    with ProcessPoolExecutor(max_workers=num_threads) as executor:
        futures = [executor.submit(insert_log_entries, batch) for batch in sql_data]
        for i, future in enumerate(as_completed(futures)):
            try:
                future.result()
                print(f"Inserted batch {i + 1}")
            except Exception as e:
                print(f"An error occurred in batch {i + 1}: {e}")

    end_time = time.time()
    generation_time = generation_end_time - start_time
    insertion_time = end_time - generation_end_time
    total_time = end_time - start_time
    entries_per_second = total_entries / insertion_time

    print(f"Total time taken: {total_time:.2f} seconds")
    print(f"Data generation time: {generation_time:.2f} seconds")
    print(f"Data insertion time: {insertion_time:.2f} seconds")
    print(f"Total entries inserted: {total_entries}")
    print(f"Insert speed: {entries_per_second:.2f} entries/second")
    print(f"Number of threads: {num_threads}")
    print(f"Total entries: {total_entries}")
    print(f"Entries per batch: {entries_per_batch}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Doris load test script")
    parser.add_argument("--num_threads", type=int, default=5, help="Number of concurrent threads")
    parser.add_argument("--total_entries", type=int, default=1000000, help="Total number of entries to insert")
    parser.add_argument("--entries_per_batch", type=int, default=1000, help="Number of entries per batch")

    args = parser.parse_args()

    main(args.num_threads, args.total_entries, args.entries_per_batch)