"""DAG 1 · lab_raw_weekly: nạp raw vault theo từng tuần (thay bài A7 tuần 3).

File này chỉ khai báo lịch, phụ thuộc và lệnh gọi. Không có SQL, không có logic biến đổi.
"""
from __future__ import annotations

import os
from datetime import timedelta
from pathlib import Path

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG
from airflow.timetables.interval import CronDataIntervalTimetable

TZ = pendulum.timezone("Asia/Ho_Chi_Minh")
REPO = Path(__file__).resolve().parents[1]
DBT_BIN = os.environ.get("DBT_BIN", str(Path.home() / "venvs/dbt/bin/dbt"))

# DAG luôn ghi vào schema <hv>_af, không bao giờ ghi vào schema chính <hv>.
_base = os.environ.get("LAB_SCHEMA", "hv00").removesuffix("_af")
AF_SCHEMA = f"{_base}_af"

default_args = {
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
    "depends_on_past": True,  # tuần sau nạp tiếp trên kết quả tuần trước
}

with DAG(
    dag_id="lab_raw_weekly",
    # CronDataIntervalTimetable: data_interval_end của lần chạy đầu = 06/03/2026 23:00 +07
    schedule=CronDataIntervalTimetable("0 23 * * 5", timezone=TZ),
    start_date=pendulum.datetime(2026, 2, 27, 23, 0, tz=TZ),
    # Chỉ dành cho lab: chặn catchup tự động ở 4 tuần của bài (logical_date cuối 20/03 -> data_interval_end 27/03),
    # nếu không scheduler sẽ tự tạo thêm các tuần đến hôm nay khi bật DAG.
    # end_date=pendulum.datetime(2026, 3, 20, 23, 0, tz=TZ),
    catchup=True,
    max_active_runs=1,
    default_args=default_args,
    tags=["finova", "w4"],
) as dag:
    build_raw = BashOperator(
        task_id="build_raw",
        # Dấu cách cuối chuỗi tránh Airflow coi chuỗi .sh là đường dẫn template.
        bash_command=f"bash {REPO}/scripts/airflow/build_raw.sh '{{{{ data_interval_end }}}}' ",
        env={"DBT_BIN": DBT_BIN, "LAB_SCHEMA": AF_SCHEMA},
        append_env=True,
    )

