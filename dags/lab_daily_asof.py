"""DAG 2 · lab_daily_asof: dựng PIT, bridge và gold cho từng phiên giao dịch (thay bài A3 tuần 3).

Ngày phiên truyền bằng {{ ds }} thay cho vòng lặp tay trong README_LAB.
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
}

with DAG(
    dag_id="lab_daily_asof",
    # Thứ 2 đến thứ 6, 18:00. CronDataIntervalTimetable: logical_date = đầu khoảng = ngày phiên,
    # nên {{ ds }} là ngày phiên, không phải ngày chạy kế tiếp.
    schedule=CronDataIntervalTimetable("0 18 * * 1-5", timezone=TZ),
    start_date=pendulum.datetime(2026, 2, 27, 18, 0, tz=TZ),
    # Chỉ dành cho lab: chặn catchup tự động ở phiên cuối của bài (27/03/2026),
    # nếu không scheduler sẽ tự tạo thêm các phiên đến hôm nay khi bật DAG.
    # end_date=pendulum.datetime(2026, 3, 27, 18, 0, tz=TZ),
    catchup=True,
    max_active_runs=1,
    default_args=default_args,
    tags=["finova", "w4"],
) as dag:
    _env = {"LAB_SCHEMA": AF_SCHEMA, "DBT_BIN": DBT_BIN}

    build_bv = BashOperator(
        task_id="build_bv",
        # HV4: lần thử 1 chạy dbt build, từ lần thử 2 chạy dbt retry; target-path riêng theo ngày.
        # Logic chọn lệnh nằm trong script, file DAG chỉ truyền ds và try_number.
        # Dấu cách cuối chuỗi tránh Airflow coi chuỗi .sh là đường dẫn template.
        bash_command=(
            f"bash {REPO}/scripts/airflow/build_bv.sh "
            "'{{ ds }}' '{{ ti.try_number }}' "
        ),
        cwd=str(REPO),
        env=_env,
        append_env=True,
    )

    build_gold_dv = BashOperator(
        task_id="build_gold_dv",
        bash_command=f"{DBT_BIN} build --selector lab_gold_dv",
        cwd=str(REPO),
        env=_env,
        append_env=True,
    )

    build_bv >> build_gold_dv

