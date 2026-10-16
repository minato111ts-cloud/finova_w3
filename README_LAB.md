# Finova Onboarding · Lab dbt trong Lakehouse

Project lab đi đủ đường dữ liệu của Finova trên bộ dữ liệu tập `luyen_tap_w3`:
staging → raw vault (hub, link, nhl, satellite) → view as-of → business vault (PIT, bridge) → gold.
Giữ nguyên star schema tuần 2 (`models/marts/star_w3`) để so hai đường dựng gold.

## Cấu trúc

| Thư mục                    | Tầng           | Vật chất hóa                                 | Nội dung                                                                                           |
| -------------------------- | -------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `models/staging/luyen_tap` | staging        | view                                         | Luật cứng, khóa băm `*_hk`, `*_hd`, `ingested_ts` giả lập                                          |
| `models/atomic/raw`        | raw vault      | incremental, append                          | `hub_customer`, `hub_account`, `hub_instrument`, `link_customer_account`, `nhl_order`, 3 satellite |
| `models/asof`              | as-of          | view                                         | Lọc phiên bản theo GUC `finova.asof_cutoff`                                                        |
| `models/atomic/bv`         | business vault | incremental, delete+insert theo `as_of_date` | `pit_customer_daily`, `bridge_customer_account`                                                    |
| `models/marts/gold_dv`     | gold           | table, có contract                           | `dim_customer_dv`, `fact_order_dv` dựng từ vault                                                   |
| `models/marts/star_w3`     | gold           | table                                        | Star schema tuần 2 dựng thẳng từ staging                                                           |
| `macros/dv`                | —              | —                                            | Mẫu nạp `dv_hub`, `dv_link`, `dv_sat`; cửa sổ nạp; test `dv_*`                                     |
| `snapshots`                | —              | —                                            | `snap_customer_current`: minh họa dbt snapshot                                                     |

`ingested_ts` của bài lab là giả lập: 22:00 ngày nghiệp vụ, giờ Việt Nam (HEL-001 Phụ lục D.3).
Ở Finova thật, loader gán `ingested_ts` lúc ghi landing; dbt không bao giờ tự sinh.

## Chạy (Windows, PowerShell 7)

```powershell
$env:FINOVA_PG_PASSWORD = '<mật khẩu>'   # không ghi vào file
$env:LAB_DBNAME = 'test_scn'
$env:LAB_SCHEMA = 'hv01'                 # mỗi người một schema
dbt debug

# Lần đầu trên schema mới: unit test của model incremental cần bảng đích tồn tại
dbt build --selector lab_all --exclude-resource-type unit_test
dbt build --selector lab_all             # từ lần này chạy đủ, mong đợi PASS=122 WARN=2

# PIT và bridge dựng theo từng ngày D (finova-cli làm vòng lặp này ở Finova thật)
$days = psql -h 127.0.0.1 -p 5436 -U postgres -d $env:LAB_DBNAME -Atc "select date_day from $($env:LAB_SCHEMA)_mart.dim_date where is_trading_day and date_day between '2026-02-27' and '2026-03-27' order by 1"
foreach ($d in $days) { dbt build --selector lab_bv --vars "{as_of_date: '$d'}" }
dbt build --selector lab_gold_dv
```

Hai WARN là có chủ đích: `hub_account` có LTA099 và `hub_instrument` có XYZ, hai khóa chỉ thấy ở giao dịch, chưa có satellite của nguồn làm chủ.

## Con số đối chiếu

| Bảng                                                   | Số dòng      |
| ------------------------------------------------------ | ------------ |
| hub_customer / hub_account / hub_instrument            | 30 / 41 / 32 |
| link_customer_account / nhl_order                      | 40 / 2.000   |
| sat_customer / sat_account / sat_instrument            | 44 / 40 / 31 |
| pit_customer_daily (21 ngày) / bridge_customer_account | 630 / 840    |
| dim_customer_dv / fact_order_dv                        | 45 / 2.000   |

`fact_order_dv` và `fact_order` (tuần 2) gắn cùng phân khúc tại ngày đặt lệnh cho cả 2.000 lệnh; 153 lệnh không có phiên bản khách (95 lệnh khớp, 5.798.940.000 đồng).

## Bài thử

1. **Nạp theo cửa sổ.** Trên schema mới, chạy `lab_raw` bốn lần với `--vars "{hi_ts: '2026-03-06 23:00+07'}"`, rồi `03-13`, `03-20`, `infinity`. `sat_customer` lần lượt 20, 35, 44, 44 dòng và trùng khớp lần nạp một lượt.
2. **Cửa sổ sai.** Chạy lại `lab_raw` với `--vars "{lo_ts: '-infinity'}"`: satellite nhận lại 26 dòng trùng, `unique_combination` FAIL 26. Hub và nhl không đổi vì có điều kiện `not exists`.
3. **Snapshot.** `dbt snapshot`: 30 dòng, mọi `dbt_valid_from` là giờ chạy lệnh. Lịch sử A → B → A của LTC008 không còn.
4. **Chọn theo thay đổi.** Lưu `target/manifest.json` vào thư mục `prod_state`, sửa `sat_customer__luyen_tap.sql`, chạy `dbt ls -s state:modified+ --state prod_state`: 5 model.

Đã chạy trên dbt-core 1.8.10 và 1.12.5 (dbt-postgres 1.8.2 và 1.11.0), PostgreSQL 16.13. Bản 1.12 báo 35 cảnh báo `MissingArgumentsPropertyInGenericTestDeprecation`; cú pháp `arguments:` chưa có ở 1.8.
