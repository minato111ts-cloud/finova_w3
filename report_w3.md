# Báo cáo Bài tập Tuần 3 · dbt trong Lakehouse Finova (PR Description)

- **Học viên**: HV4
- **Nhánh**: `feat/w3_hv04`
- **Schema thực hành**: `hv04` (và `hv04_lo` cho bài A7)
- **Môi trường**: `dbt-core 1.12.5` + `dbt-postgres 1.11.0`, Python `3.12.15`, PostgreSQL `16`

---

## Phần A: Bài chung (A1 – A8)

### 1. Bảng tổng hợp kết quả A1 – A8

| Bài    | Lệnh đã chạy                                                                                                                                                                                                                    | Kết quả mong đợi                                                          | Kết quả thực tế                                                                                                                                                                                                                  | Giải thích                                                                                                                                                                                                                                                                                                                                                                                                |
| :----- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A1** | `dbt build --selector lab_all --exclude-resource-type unit_test`                                                                                                                                                                | `PASS 120, WARN 2`                                                        | `PASS=120 WARN=2 ERROR=0 SKIP=0`                                                                                                                                                                                                 | 122 = 31 model + 2 seed + 89 data test; với 120 đạt và 2 warn đến từ macros/dv/dv_tests.sql; --exclude-resource-type unit_test cần phải có lệnh này vì \_raw_vault\_\_models.yml có input: this => tức giả lập nội dung bảng đích của model incremental tuy nhiên thì bảng chưa tồn tại                                                                                                                   |
| **A2** | `dbt build --selector lab_all`                                                                                                                                                                                                  | `PASS 122, WARN 2 (LTA099, XYZ)`                                          | `PASS=122 WARN=2 ERROR=0 SKIP=0` (2 WARN tại `hub_account` - `LTA099` và `hub_instrument` - `XYZ`)                                                                                                                               | Bên cạnh 120 node như A1 thì có 2 thêm 2 unit tests được chạy nữa có tổng cộng 124 node với 122 pass                                                                                                                                                                                                                                                                                                      |
| **A3** | Chạy vòng lặp 21 ngày giao dịch (`2026-02-27` → `2026-03-27`) với `dbt build --selector lab_bv --vars "{as_of_date: '$d'}"`, sau đó `dbt build --selector lab_gold_dv`                                                          | `630 dòng PIT, 840 dòng bridge`                                           | `pit_customer_daily`: **630 dòng** (30 khách × 21 phiên)<br>`bridge_customer_account`: **840 dòng** (40 cặp × 21 phiên)                                                                                                          | Đạt ; Lấy các ngày trading và nằm trong khoảng 27/02/2026-10/04/2026 => Có tổng cộng 21 ngày                                                                                                                                                                                                                                                                                                              |
| **A4** | Truy vấn đối chiếu `fact_order_dv` với `fact_order` theo `order_id` tại ngày đặt lệnh                                                                                                                                           | `0 lệnh lệch; 153 lệnh không xác định (95 lệnh khớp, 5.798.940.000 đồng)` | `0 lệnh lệch`; `153 lệnh UNKNOWN` (`95 lệnh FILLED`, tổng giá trị khớp `5.798.940.000` đồng)                                                                                                                                     | Đạt                                                                                                                                                                                                                                                                                                                                                                                                       |
| **A5** | `dbt build --selector lab_raw --vars "{lo_ts: '-infinity'}"` sau đó khôi phục bằng `dbt build --selector lab_raw --full-refresh`                                                                                                | `sat_customer__luyen_tap: 44 → 70 dòng, FAIL 26; khôi phục về 44`         | Chạy `lo_ts: '-infinity'`: `sat_customer__luyen_tap` tăng từ **44 → 70 dòng**, test `unique_combination` báo **FAIL 26**, `dv_no_redundant_versions` báo **WARN 26**. Chạy `--full-refresh`: khôi phục về **44 dòng**, test PASS | lo_ts: '-infinity' sẽ ép dbt quên mốc cũ và tiến hành nạp lại từ đầu. Đối với tệp khách chưa từng thay đổi sẽ không phát sinh dòng nào, tuy nhiên với khách đã đổi thì sẽ phát sinh thêm dòng ví dụ: Khách B tại thời điểm a là thường nâng lên VIP ở thời điểm b thì sau khi bị ép quên đi mốc cũ, máy sẽ đọc lại khách A là thường so với bản mới nhất là VIP => Thêm dòng trong khi đây là dữ liệu lặp |
| **A6** | `dbt snapshot`, sau đó đối chiếu `snap_customer_current` với `sat_customer__luyen_tap`                                                                                                                                          | `30 dòng có cùng dbt_valid_from, so với 44 phiên bản`                     | `snap_customer_current`: **30 dòng** (mọi dòng có cùng `dbt_valid_from` là thời điểm chạy lệnh, mất lịch sử A → B → A của `LTC008`), so với **44 phiên bản** trong `sat_customer__luyen_tap`                                     | Snapshots sẽ lấy mốc thời gian tại thời điểm gõ lệnh => Bảng chỉ có 30 khách hàng khi thực thi lệnh dbt snapshots sẽ capture lại 30 khách tại thời điểm đấy mà không thể lấy được toàn bộ lịch sử 44 dòng                                                                                                                                                                                                 |
| **A7** | Đặt `$env:LAB_SCHEMA = 'hv04_lo'`, chạy `dbt build --selector lab_raw --vars "{hi_ts: '<mốc>'}"` qua 4 lô (`2026-03-06 23:00+07`, `2026-03-13 23:00+07`, `2026-03-20 23:00+07`, `infinity`), so với `hv04_atomic` bằng `EXCEPT` | `sat_customer__luyen_tap lần lượt 20, 35, 44, 44 dòng; 0 dòng lệch`       | Số dòng sau 4 lô lần lượt: **20, 35, 44, 44 dòng**. Đối chiếu 2 chiều bằng `EXCEPT` với `hv04_atomic.sat_customer__luyen_tap`: **0 dòng lệch**                                                                                   | Đạt                                                                                                                                                                                                                                                                                                                                                                                                       |
| **A8** | Chép `target/manifest.json` vào `prod_state/`, thêm 1 dòng comment vào `sat_customer__luyen_tap.sql`, chạy `dbt ls -s state:modified+ --state prod_state --resource-type model`                                                 | `5 model`                                                                 | **5 model**: `sat_customer__luyen_tap`, `asof__sat_customer__luyen_tap`, `pit_customer_daily`, `dim_customer_dv`, `fact_order_dv`                                                                                                | Lý do ra số dòng khác nhau là thời điểm ingested_ts được nạp vào; ở 2 lệnh cuối số dòng bằng nhau do set giới hạn cuối về time là 20/3/2026 chính là infinity luôn                                                                                                                                                                                                                                        |

---

### 2. Chi tiết các lệnh & truy vấn đối chiếu ở Phần A

#### Bài A3: Vòng lặp dựng PIT và Bridge cho 21 ngày giao dịch

```powershell
$days = psql -h 192.168.26.212 -p 5432 -U hv04 -d $env:LAB_DBNAME -Atc "select date_day from $($env:LAB_SCHEMA)_mart.dim_date where is_trading_day and date_day between '2026-02-27' and '2026-03-27' order by 1"
foreach ($d in $days) { dbt build --selector lab_bv --vars "{as_of_date: '$d'}" }
dbt build --selector lab_gold_dv
```

#### Bài A4: Truy vấn đối chiếu `fact_order_dv` và `fact_order`

```sql
-- 1. Kiểm tra số lệnh lệch phân khúc giữa 2 đường dựng Gold:
with dv as (
	select
		dc.segment as segment_dv,
		fo.filled_qty,
		fo.filled_value,
		fo.order_id,
		fo.customer_key
	from hv04_mart.fact_order fo
	join hv04_mart.dim_customer dc on fo.customer_key = dc.customer_key
),
star as (
	select
		dcd.segment as segment_star,
		fod.filled_value,
		fod.order_id,
		fod.customer_key
	from hv04_mart.fact_order_dv fod
	join hv04_mart.dim_customer_dv dcd on fod.customer_key = dcd.customer_key
)
select
	count(*) as tong_so_lenh,
	count(case when dv.segment_dv is distinct from star.segment_star then 1 end) as so_lenh_lech,
	count(case when dv.segment_dv = 'UNKNOWN' then 1 end) as so_lenh_unknown,
	count(case when dv.segment_dv = 'UNKNOWN' and dv.filled_qty > 0 then 1 end) as so_lenh_khop_khong_xac_dinh,
	sum(case when dv.segment_dv = 'UNKNOWN' and dv.filled_qty > 0 then dv.filled_value end) as tong_gia_tri_lenh_khong_xac_dinh
from dv
join star on dv.order_id = star.order_id
```

#### Bài A7: Truy vấn đối chiếu hai schema `hv04_atomic` và `hv04_lo_atomic`

```sql
(
	select customer_hk, ingested_ts, hash_diff from hv04_atomic.sat_customer__luyen_tap
	except
	select customer_hk, ingested_ts, hash_diff from hv04_lo_atomic.sat_customer__luyen_tap
)
union all
(
	select  customer_hk, ingested_ts, hash_diff from hv04_lo_atomic.sat_customer__luyen_tap
	except
	select customer_hk, ingested_ts, hash_diff from hv04_atomic.sat_customer__luyen_tap
)
-- Kết quả: 0 dòng (0 rows)
```

---

## Phần B: Bài riêng của HV4 (Model `bridge_customer_account`)

### B1. Singular Test và Unit Test cho `bridge_customer_account`

#### 1. Nội dung Singular Test (`tests/lab/hv04_A4.sql`)

- **Quy tắc kiểm tra**: Số dòng trong `bridge_customer_account` tại mỗi ngày `D` (`as_of_date`) phải bằng đúng số dòng trong `link_customer_account` có `ingested_ts <= cutoff_ts` của ngày `D`.

```sql
with bridge_per_day as (
    select
        as_of_date,
        cutoff_ts,
        count(*) as bridge_cnt
    from {{ ref('bridge_customer_account') }}
    group by
        as_of_date,
        cutoff_ts
),

link_per_day as (
    select
        b.as_of_date,
        b.cutoff_ts,
        b.bridge_cnt,
        count(l.link_customer_account_hk) as link_cnt
    from bridge_per_day b
    left join {{ ref('link_customer_account') }} l
        on l.ingested_ts <= b.cutoff_ts
    group by
        b.as_of_date,
        b.cutoff_ts,
        b.bridge_cnt
)

select
    as_of_date,
    cutoff_ts,
    bridge_cnt,
    link_cnt
from link_per_day
where bridge_cnt <> link_cnt
```

#### 2. Nội dung Unit Test (`models/atomic/bv/hv04.yml`)

- **Ca biên kiểm tra**: Bản ghi liên kết về muộn sau `cutoff_ts` (`event_ts` ngày `10/03` nhưng `ingested_ts` là `07:00 ngày 11/03`, sau mốc cutoff `06:00 ngày 11/03`) không được xuất hiện trong bridge ngày `10/03`.

```yaml
unit_tests:
  - name: ut_hv04_bridge_excludes_late_link_after_cutoff
    description: "HV4 Unit Test: Link mới về sau cutoff của D không xuất hiện trong bridge ngày D"
    model: bridge_customer_account
    overrides:
      macros:
        is_incremental: false
        get_asof_date: "'2026-03-10'::date"
        get_asof_cutoff: "'2026-03-11 06:00:00+07'::timestamptz"
    given:
      - input: ref('asof__link_customer_account')
        rows:
          - link_customer_account_hk: '\x01'
            customer_hk: '\x11'
            account_hk: '\x21'
            ingested_ts: "2026-03-10 22:00:00+07"
            event_ts: "2026-03-10 00:00:00+07"
            record_source: "luyen_tap.accounts"
          - link_customer_account_hk: '\x02'
            customer_hk: '\x12'
            account_hk: '\x22'
            ingested_ts: "2026-03-11 06:00:00+07"
            event_ts: "2026-03-10 00:00:00+07"
            record_source: "luyen_tap.accounts"
          - link_customer_account_hk: '\x03'
            customer_hk: '\x13'
            account_hk: '\x23'
            ingested_ts: "2026-03-11 07:00:00+07"
            event_ts: "2026-03-10 00:00:00+07"
            record_source: "luyen_tap.accounts"
    expect:
      rows:
        - as_of_date: "2026-03-10"
          cutoff_ts: "2026-03-11 06:00:00+07"
        - as_of_date: "2026-03-10"
          cutoff_ts: "2026-03-11 06:00:00+07"
```

#### 3. Cố ý làm hỏng model sau đó khắc phục (Test ĐỎ → Sửa lại Test XANH)

- **Khi cố ý làm hỏng điều kiện lọc cutoff** (bỏ `where ingested_ts <= {{ get_asof_cutoff() }}` hoặc đổi `<=` thành `<`):
  ```text
  1 of 5 FAIL 1 bridge_customer_account::ut_hv04_bridge_excludes_late_link_after_cutoff [FAIL 1 in 0.15s]
  2 of 5 SKIP relation hv04_atomic.bridge_customer_account ............................ [SKIP]
  3 of 5 SKIP test hv04_A4 ............................................................ [SKIP]
  Done. PASS=1 WARN=0 ERROR=1 SKIP=3 TOTAL=5
  ```
- **Khi khôi phục lại điều kiện đúng (`ingested_ts <= {{ get_asof_cutoff() }}`)**:
  ```text
  1 of 5 PASS bridge_customer_account::ut_hv04_bridge_excludes_late_link_after_cutoff . [PASS in 0.14s]
  2 of 5 PASS bridge_customer_account::ut_hv04_bridge_nap_lai_khong_sinh_dong_trung ... [PASS in 0.12s]
  3 of 5 OK created sql incremental model hv04_atomic.bridge_customer_account ......... [INSERT 0 40 in 0.18s]
  4 of 5 PASS hv04_A4 ................................................................. [PASS in 0.08s]
  5 of 5 PASS unique_combination_bridge_customer_account_account_hk__as_of_date ....... [PASS in 0.07s]
  Done. PASS=5 WARN=0 ERROR=0 SKIP=0 TOTAL=5
  ```

---

### B2. Gây lỗi SQL và `dbt retry`

#### 1. Các lệnh đã thực hiện

```powershell
# 1. Cố ý gây lỗi cú pháp SQL trong model dim_customer_dv.sql và chạy build lần 1:
dbt build --selector lab_all --log-path run1 --target-path run1/target

# 2. Sửa lại lỗi SQL trong dim_customer_dv.sql
git checkout models/marts/gold_dv/dim_customer_dv.sql

# 3. Chép thư mục run1/target sang run2/target để giữ nguyên run_results.json của lần 1:
Copy-Item -Recurse -Force run1\target run2\target

# 4. Chạy dbt retry trên bản chép run2:
dbt retry --log-path run2 --target-path run2/target
```

#### 2. Hai file kết quả đính kèm

- run1/target/run_results.json (Ghi nhận trạng thái lỗi ở lần chạy 1).
- run2/target/run_results.json (Ghi nhận trạng thái chạy lại thành công ở lần 2).

#### 3. Giải thích kết quả `dbt retry` (2–3 câu theo yêu cầu đề bài)

1. Ở lần chạy 1 (`run1`), việc cố ý gây lỗi SQL tại model `model.finova_dbt_lab.dim_customer_dv` khiến node này dừng với trạng thái `error`, đồng thời kéo theo 1 node phụ thuộc phía sau là `test.finova_dbt_lab.relationships_fact_order_dv_customer_key__customer_key__ref_dim_customer_dv_` bị đánh dấu `skipped` (trong khi các node độc lập khác đã chạy xong và đạt `pass`/`warn`).
2. Khi chạy `dbt retry` ở lần 2 (`run2`), dbt đọc file `run_results.json` tại `run2/target` và **chỉ thực thi lại đúng 2 node chưa thành công** ở lần trước là `model.finova_dbt_lab.dim_customer_dv` (trước đó `error`) và `test.finova_dbt_lab.relationships_fact_order_dv_customer_key__customer_key__ref_dim_customer_dv_` (trước đó `skipped`), hoàn toàn bỏ qua hơn 120 node đã `pass`.
3. Sau khi lỗi SQL ở `dim_customer_dv` được khắc phục, cả 2 node này đã chạy lại thành công (`INSERT 0 45` và `PASS`) chỉ trong `0.53s`.

---

### B3. Macro mẫu nạp `T-BRIDGE` (`dv_bridge`)

#### 1. Định nghĩa macro mẫu nạp `T-BRIDGE` tại macros/dv/dv_bridge.sql

```sql
{#- Mẫu nạp T-BRIDGE (FNV-ELT-SLV-TQ / FNV-ELT-SLV-BV):
    Dựng bảng Bridge làm phẳng đường đi quan hệ tại thời điểm cutoff của ngày D.
    - Lọc bản ghi nguồn có ingested_ts <= cutoff_ts của ngày D.
    - Khử trùng theo grain_hk (giữ bản ghi có ingested_ts sớm nhất) để đảm bảo tính idempotent khi nạp lại. -#}

{% macro dv_bridge(grain_hk, hk_cols, source) -%}
with w as (
    select *
    from {{ ref(source) }}
    where ingested_ts <= {{ get_asof_cutoff() }}
      and {{ grain_hk }} is not null
)
select distinct on (w.{{ grain_hk }})
    {{ get_asof_date() }}   as as_of_date,
    w.{{ grain_hk }},
    {%- for c in hk_cols %}
    w.{{ c }},
    {%- endfor %}
    {{ get_asof_cutoff() }} as cutoff_ts
from w
order by w.{{ grain_hk }}, w.ingested_ts
{%- endmacro %}
```

#### 2. Áp dụng macro vào models/atomic/bv/bridge_customer_account.sql

```sql
-- Grain: 1 dòng = 1 tài khoản × 1 ngày D, kèm khách sở hữu. Làm phẳng đường khách → tài khoản (mẫu T-BRIDGE)
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='as_of_date',
    pre_hook="{{ asof_set_session() }}"
) }}
{{ dv_bridge(
    grain_hk='account_hk',
    hk_cols=['customer_hk', 'link_customer_account_hk'],
    source='asof__link_customer_account'
) }}
```

#### 3. Unit Test cho Ca chính và Ca nạp lại models/atomic/bv/hv04.yml

- **Ca chính** (`ut_hv04_bridge_excludes_late_link_after_cutoff`): Kiểm tra lọc đúng các liên kết có `ingested_ts <= cutoff_ts` và loại bỏ liên kết về muộn sau `cutoff_ts`.
- **Ca nạp lại** (`ut_hv04_bridge_nap_lai_khong_sinh_dong_trung`): Kiểm tra khi cùng một tài khoản (`\x21`) xuất hiện lặp lại ở lô sau trước cutoff (`05/03` và `10/03`), macro `dv_bridge` khử trùng theo `grain_hk` và chỉ giữ đúng **1 dòng duy nhất** tại ngày `as_of_date = 2026-03-10`.

---

## Phần C: Câu hỏi tự kiểm của HV4 (C5 & C8)

### C5. Satellite giữ phiên bản theo `ingested_ts`; snapshot giữ theo gì? Vì sao Finova không dùng snapshot cho atomic?

- **Trả lời**:
  1. **Mốc thời gian**:
     - **Satellite (`sat_customer__luyen_tap`)**: Giữ lịch sử phiên bản theo **`ingested_ts`** (thời điểm hệ thống nhận bản ghi tại landing, trong lab giả lập là `22:00` ngày nghiệp vụ).
     - **dbt Snapshot (`snap_customer_current`)**: Với chiến lược `check`, dbt lấy **giờ chạy lệnh thực tế của hệ thống (`now()` / `current_timestamp`)** để gán cho cột `dbt_valid_from` và `dbt_valid_to`.
  2. **Vì sao Finova không dùng `dbt snapshot` cho tầng Atomic**:
     - **Không tái lập được quá khứ (Không Idempotent / Không Replay được)**: `dbt snapshot` phụ thuộc vào thời điểm chạy lệnh vật lý và bỏ qua cờ `--full-refresh`. Nếu dựng lại kho từ dữ liệu lịch sử, tất cả các dòng đều nhận cùng một giờ `dbt_valid_from` là lúc chạy lệnh.
     - **Làm mất lịch sử thay đổi giữa hai lần chụp (và lịch sử A → B → A)**: Vì bảng snapshot đọc trạng thái cuối hoặc quét một lần tại giờ chạy, mọi biến động trung gian (như khách `LTC008` chuyển từ `VIP` ngày 03/03 → `AFFLUENT` ngày 11/03 → quay lại `VIP` ngày 20/03) bị gộp mất hoặc chỉ còn lại trạng thái cuối, không thể phục vụ backtest theo thời điểm `as-of` (vi phạm **QT-NO-NOW** và **INV-T2/INV-T3**).
- **Bằng chứng (Bài A6)**:

  ```sql
  -- 1. Kiểm tra bảng snapshot:
  SELECT count(*) AS total_rows, count(DISTINCT dbt_valid_from) AS distinct_valid_from
  FROM hv04_snapshots.snap_customer_current;
  -- Kết quả: total_rows = 30 | distinct_valid_from = 1 (cả 30 dòng có cùng 1 mốc dbt_valid_from là giờ chạy lệnh)

  -- 2. Kiểm tra bảng satellite:
  SELECT count(*) AS total_rows, count(DISTINCT ingested_ts) AS distinct_ingested_ts
  FROM hv04_atomic.sat_customer__luyen_tap;
  -- Kết quả: total_rows = 44 (44 phiên bản lịch sử, giữ đủ 3 phiên bản VIP -> AFFLUENT -> VIP của LTC008)
  ```

---

### C8. `dbt run` khác `dbt build` ở đâu, và Helios đã trả giá gì vì dùng `dbt run`?

- **Trả lời**:
  1. **Sự khác biệt giữa `dbt run` và `dbt build`**:
     - **`dbt run`**: Chỉ thực thi việc dựng các **model** (view, table, incremental) từ đầu đến cuối DAG, hoàn toàn **không chạy bất kỳ test nào** (và cũng không chạy seed hay snapshot). Do đó, nếu một model ở tầng trên (như Staging hoặc Vault) tính toán sai logic hoặc sinh dòng trùng nhưng không lỗi cú pháp SQL, `dbt run` vẫn tiếp tục chạy và đẩy dữ liệu sai đó tràn xuống dựng toàn bộ các bảng hạ nguồn (Gold / Mart).
     - **`dbt build`**: Thực thi **seed, model, snapshot và test đan xen nhau theo thứ tự phụ thuộc của DAG**. Ngay sau khi một model được dựng xong, mọi data test của model đó được chạy ngay lập tức; nếu có bất kỳ test nào mức `ERROR` bị đỏ (`FAIL`), `dbt build` sẽ **chặn đứng (SKIP) toàn bộ các model hạ nguồn phía sau**, ngăn không cho dữ liệu bẩn lan truyền lên tầng báo cáo/API.
  2. **Cái giá mà dự án Helios đã phải trả vì dùng `dbt run`**:
     - Trong dự án triển khai Lakehouse trước kia (Helios), pipeline chỉ gọi `dbt run` mà không chặn bằng test thông qua `dbt build`. Khi dữ liệu nguồn/cửa sổ nạp gặp lỗi làm sai lệch số dư/phiên bản ở tầng dưới, không có chốt chặn nào dừng pipeline lại; dữ liệu sai vẫn âm thầm chảy thẳng lên tầng Gold/Mart và hiển thị số sai cho người dùng cuối / engine mà hệ thống không hề báo lỗi kỹ thuật.
