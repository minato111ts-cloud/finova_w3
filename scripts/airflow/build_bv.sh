#!/usr/bin/env bash
# Gọi từ task build_bv của DAG lab_daily_asof (bài HV4).
# Đối số: $1 = ds (ngày phiên D), $2 = try_number của task trong Airflow.
#   Lần thử 1        : dbt build --selector lab_bv --vars as_of_date=D
#   Lần thử từ 2 trở đi: dbt retry (chỉ chạy lại node lỗi và node con bị bỏ qua)
# Mỗi ngày D dùng --target-path riêng (target/bv_<D>) để run_results.json của ngày này
# không bị ngày khác ghi đè; dbt retry đọc đúng file này.
# Biến môi trường bắt buộc: DBT_BIN, FINOVA_PG_* và LAB_SCHEMA. Không in biến môi trường (INV-S4).
set -euo pipefail

DS="${1:?thiếu ds}"
TRY="${2:?thiếu try_number}"
: "${DBT_BIN:?thiếu DBT_BIN}"
cd "$(dirname "$0")/../.."

TARGET_PATH="target/bv_${DS}"
RESULTS="${TARGET_PATH}/run_results.json"

if [ "$TRY" -gt 1 ]; then
  if [ -f "$RESULTS" ]; then
    echo "Lần thử ${TRY}: dbt retry theo ${RESULTS}"
    exec "$DBT_BIN" retry --target-path "$TARGET_PATH"
  fi
  echo "Lần thử ${TRY} nhưng chưa có ${RESULTS}: chạy dbt build"
fi

echo "Lần thử ${TRY}: dbt build --selector lab_bv cho ${DS}"
exec "$DBT_BIN" build --selector lab_bv --vars "{as_of_date: '${DS}'}" --target-path "$TARGET_PATH"

