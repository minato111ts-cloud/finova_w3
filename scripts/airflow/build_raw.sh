#!/usr/bin/env bash
# Gọi từ task build_raw của DAG lab_raw_weekly.
# Đối số: $1 = hi_ts (data_interval_end). Chỉ truyền hi_ts, không truyền lo_ts (tránh lỗi A5 tuần 3).
# Biến môi trường bắt buộc: DBT_BIN, FINOVA_PG_* và LAB_SCHEMA (DAG đặt LAB_SCHEMA=<hv>_af).
# Không in biến môi trường (INV-S4).
set -euo pipefail

HI_TS="${1:?thiếu hi_ts}"
: "${DBT_BIN:?thiếu DBT_BIN}"
cd "$(dirname "$0")/../.."

# Lần đầu trên schema mới chưa có bảng đích nên unit test của model incremental sẽ lỗi.
# Quyết định theo trạng thái thật của DB (bảng đã tồn tại chưa), không theo ngày chạy:
# Clear rồi chạy lại lần đầu vẫn đúng, vì lúc đó bảng chưa có thì bỏ unit test, có rồi thì chạy đủ.
CHECK_OUT="$("$DBT_BIN" run-operation af_raw_targets_exist --quiet)"
echo "$CHECK_OUT" | grep -E 'AF_RAW_TARGETS_EXIST=' || { echo "Không đọc được trạng thái bảng đích"; exit 1; }

# Khi bảng đích đã tồn tại: chạy unit test TRƯỚC khi build model để chặn sớm nếu logic SQL sai
# (đúng ngữ nghĩa của dbt build). Không truyền hi_ts vào lệnh unit_test vì ut_sat_customer_aba_ra_ba_phien_ban
# có dữ liệu mẫu ngày 09/03; nếu truyền hi_ts=06/03 (khi Clear chạy lại tuần 1) sẽ bị lọc mất dòng 09/03.
if echo "$CHECK_OUT" | grep -q 'AF_RAW_TARGETS_EXIST=false'; then
  echo "Bảng đích chưa đầy đủ: bỏ unit test ở lần này"
else
  "$DBT_BIN" build --selector lab_raw --resource-type unit_test
fi

exec "$DBT_BIN" build --selector lab_raw --vars "{hi_ts: '${HI_TS}'}" --exclude-resource-type unit_test

