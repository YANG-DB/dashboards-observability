CREATE MATERIALIZED VIEW IF NOT EXISTS {table_name}__window_agg_60_min_network_ip_cardinality_mview AS
WITH hourly_buckets AS (
    SELECT
      date_trunc('hour', from_unixtime(start_time / 1000)) AS interval_start_time,
      CAST(IFNULL(dst_endpoint.ip, '0.0.0.0') AS STRING)  AS dstaddr,
      COUNT(*) AS total_count
   FROM
      {table_name}
    GROUP BY
      interval_start_time,
      dstaddr
  ),
  ranked_addresses AS (
    SELECT
      CAST(interval_start_time  AS TIMESTAMP),
      dstaddr,
      total_count,
      RANK() OVER (PARTITION BY interval_start_time ORDER BY total_count DESC) AS addr_rank
    FROM
      hourly_buckets
  )
  SELECT
    CAST(interval_start_time  AS TIMESTAMP),
    dstaddr,
    total_count
  FROM
    ranked_addresses
  WHERE
      addr_rank <= 50
  ORDER BY
    interval_start_time ASC,
    addr_rank ASC
WITH (
  auto_refresh = true,
  refresh_interval = '60 min',
  checkpoint_location = '{s3_checkpoint_location}',
  watermark_delay = '60 min',
  extra_options = '{ "{table_name}": { "maxFilesPerTrigger": "10" }}'
)

