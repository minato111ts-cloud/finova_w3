**Bài tập tuần 3 · dbt trong Lakehouse Finova**

**Hạn nộp:** \_\_\_\_\_\_\_\_\_\_\_\_

**Tài liệu kèm theo:** finova\_dbt\_lab.zip, FNV-GUIDE-DBT v1.0, deck "dbt trong Lakehouse Finova"

|**Học viên**|**LAB\_SCHEMA**|
| :- | :- |
|HV1|hv01|
|HV2|hv02|
|HV3|hv03|
|HV4|hv04|
|HV5|hv05|

# **Chuẩn bị**
1. Cài dbt theo FNV-GUIDE-DBT mục 4. Chạy dbt --version và kiểm tra ra đúng một trong hai cặp ghim:
   - dbt-core 1.8.10 + dbt-postgres 1.8.2
   - dbt-core 1.12.5 + dbt-postgres 1.11.0
1. Chép profiles.yml.example sang ~/.dbt/profiles.yml.
1. Đặt biến môi trường trong phiên PowerShell. Không ghi mật khẩu vào bất kỳ file nào.

   $env:FINOVA\_PG\_PASSWORD = '<mật khẩu>'

   $env:LAB\_DBNAME = 'test\_scn'

   $env:LAB\_SCHEMA = 'hv0X'

1. Chạy dbt debug, phải ra All checks passed.
1. **Chỉ HV1 làm bước này, làm một lần trước khi cả nhóm bắt đầu:** nạp dữ liệu raw luyen\_tap\_w2 vào database test\_scn.

   $env:PGCLIENTENCODING = 'UTF8'

   psql -h 127.0.0.1 -p 5436 -U postgres -d test\_scn -v ON\_ERROR\_STOP=1 -f data/w2\_raw\_luyen\_tap\_w2.sql

   Script này xóa rồi tạo lại schema luyen\_tap\_w2, nên không chạy lại khi người khác đang build.

Quy ước dùng lệnh dbt:

- Dựng model và chạy test: chỉ dùng dbt build --selector <tên>, **không dùng dbt run**.
- dbt snapshot (A6), dbt ls (A8) và dbt retry (B2) là lệnh bài yêu cầu, được phép dùng.
# **Phần A: bài chung (cả 5 người, làm theo thứ tự)**

|**Bài**|**Việc**|**Kết quả mong đợi**|
| :- | :- | :- |
|A1|dbt build --selector lab\_all --exclude-resource-type unit\_test|PASS 120, WARN 2|
|A2|dbt build --selector lab\_all|PASS 122, WARN 2 (LTA099, XYZ)|
|A3|Dựng PIT và bridge cho 21 phiên bằng vòng lặp trong README\_LAB, mục "Chạy". Sau đó chạy dbt build --selector lab\_gold\_dv|630 dòng PIT, 840 dòng bridge|
|A4|Join fact\_order\_dv với fact\_order theo order\_id, so phân khúc khách tại ngày đặt lệnh|0 lệnh lệch; 153 lệnh không xác định (95 lệnh khớp, 5.798.940.000 đồng)|
|A5|dbt build --selector lab\_raw --vars "{lo\_ts: '-infinity'}", sau đó khôi phục bằng dbt build --selector lab\_raw --full-refresh|sat\_customer\_\_luyen\_tap: 44 → 70 dòng, FAIL 26; khôi phục về 44|
|A6|dbt snapshot, rồi so với sat\_customer\_\_luyen\_tap|30 dòng có cùng dbt\_valid\_from, so với 44 phiên bản|
|A7|Nạp raw vault theo 4 lô vào schema mới (xem ghi chú bên dưới), rồi so với schema chính|sat\_customer\_\_luyen\_tap lần lượt 20, 35, 44, 44 dòng; 0 dòng lệch|
|A8|Chép target/manifest.json vào prod\_state/, thêm một dòng comment vào sat\_customer\_\_luyen\_tap.sql, chạy dbt ls -s state:modified+ --state prod\_state|5 model|

Ghi chú cho A7:

- Đặt $env:LAB\_SCHEMA = 'hv0X\_lo'.
- Lô 1 thêm --exclude-resource-type unit\_test, vì unit test cần bảng đích đã tồn tại.
- Chạy dbt build --selector lab\_raw --vars "{hi\_ts: '<giá trị>'}" lần lượt với 4 giá trị: 2026-03-06 23:00+07, 2026-03-13 23:00+07, 2026-03-20 23:00+07, infinity.
- So hai schema bằng EXCEPT theo (customer\_hk, ingested\_ts, hash\_diff).
- Làm xong, đặt LAB\_SCHEMA về lại hv0X.

Nếu kết quả của bạn lệch so với cột mong đợi, giải thích lý do trong PR.
# **Phần B: bài riêng**
## **B1. Singular test và unit test cho model được giao**
Mỗi người viết cho model được giao:

- 1 singular test, đặt tại tests/lab/assert\_hv0X\_<tên>.sql.
- 1 unit test, đặt trong file yml của model. Unit test phải có ít nhất một ca biên mà dữ liệu tập không có: A → B → A, nạp lại cùng nội dung, bản ghi về muộn, hoặc ngày nghỉ giao dịch.

Sau đó cố ý làm hỏng model để test đỏ, rồi sửa lại để test xanh.

Các test unique, not\_null, relationships trên khóa đã có sẵn trong yml của lab. Không viết lại các test đó.

|**Học viên**|**Model**|**Gợi ý singular test**|**Gợi ý unit test**|
| :- | :- | :- | :- |
|HV1|hub\_account|ingested\_ts của mỗi khóa bằng lần thấy sớm nhất trên cả 3 nguồn: accounts, orders, cash\_txn|Lô 2 chứa lại khóa cũ: không sinh dòng mới, không đổi ingested\_ts|
|HV2|link\_customer\_account|Mọi cặp khách–tài khoản trong stg\_luyen\_tap\_\_accounts đều có trong link|Cùng cặp xuất hiện lại ở lô sau: không sinh dòng mới|
|HV3|pit\_customer\_daily|Mỗi con trỏ khác rỗng phải trỏ tới phiên bản có thật trong satellite và có ingested\_ts ≤ cutoff\_ts|Bản ghi về sau cutoff không được lọt vào PIT của ngày D|
|HV4|bridge\_customer\_account|Số dòng bridge ngày D bằng số dòng link có ingested\_ts ≤ cutoff\_ts của D|Link mới về sau cutoff của D không xuất hiện trong bridge ngày D|
|HV5|fact\_order\_dv|Số lệnh và tổng giá trị khớp bằng fact\_order|Lệnh không có phiên bản khách nhận khóa "không xác định", không bị rơi khỏi fact|

## **B2. Gây lỗi và dbt retry**
1. Cố ý gây một lỗi SQL trong một model.
1. Chạy build và để lỗi xảy ra:

   dbt build --selector lab\_all --log-path run1 --target-path run1/target

1. Sửa lỗi.
1. Chép thư mục run1/target thành run2/target.
1. Chạy retry trên bản chép:

   dbt retry --log-path run2 --target-path run2/target

dbt retry đọc run\_results.json ở target path, nên phải chép trước khi retry. Nhờ vậy run1 giữ kết quả lỗi, còn run2 giữ kết quả retry.

Nộp: hai file run\_results.json, kèm 2–3 câu cho biết retry đã chạy lại những node nào và vì sao.
## **B3. Macro mẫu nạp T-\* mới**
1. Đọc FNV-ELT-SLV-TQ mục 6–8.
1. Chọn một mẫu nạp T-\* chưa có trong lab. Lab đã có dv\_hub, dv\_link, dv\_sat.
1. Đăng ký mẫu với mentor trước khi làm. Hai người không được chọn trùng mẫu.
1. Viết mẫu thành macro trong macros/dv/, kèm unit test cho ca chính và ca nạp lại.
# **Phần C: câu hỏi tự kiểm**
Mỗi người trả lời đủ 8 câu bằng văn bản. Ở buổi review, mỗi người trình bày các câu được giao.

Bằng chứng kèm theo câu trả lời:

- C1, C2, C5, C6, C7: query hoặc số dòng trên schema của mình.
- C3, C4: output lệnh chạy thật.
- C8: dẫn mục tài liệu.

|**Câu**|**Câu hỏi**|**Trình bày**|
| :- | :- | :- |
|C1|Hub giữ ingested\_ts của lần nào? Vì sao không lấy lần mới nhất?|HV1|
|C2|PIT ngày 05/03 trỏ phiên bản nào của LTC008? Nếu bản ghi ngày 11/03 về lúc 07:00 ngày 12/03, PIT ngày 11/03 trỏ đâu?|HV2|
|C3|Vì sao pip install dbt-postgres==1.8.2 không cho dbt-core 1.8? Cài thế nào để chắc đúng bản?|HV3|
|C4|Thiếu biến FINOVA\_PG\_PASSWORD, dbt báo lỗi gì, và vì sao không phải "Env var required"?|HV3|
|C5|Satellite giữ phiên bản theo ingested\_ts; snapshot giữ theo gì? Vì sao Finova không dùng snapshot cho atomic?|HV4|
|C6|Vì sao chạy lại cửa sổ nạp từ đầu làm satellite có dòng trùng, còn hub thì không?|HV1|
|C7|Khi nào incremental\_strategy='delete+insert' để lại dòng cũ của ngày D, còn pre\_hook xóa ngày D thì không?|HV5|
|C8|dbt run khác dbt build ở đâu, và Helios đã trả giá gì vì dùng dbt run?|HV4|

# **Nộp bài**
Mở PR từ nhánh feat/w3-lab-hv0X. Mô tả PR gồm:

- **Phần A:** bảng A1–A8, mỗi bài ghi lệnh đã chạy, kết quả thực tế và kết quả mong đợi.
- **Phần B:** diff của test và macro, log khi test đỏ, log khi test xanh, và hai file run\_results.json.
- **Phần C:** câu trả lời cho 8 câu hỏi.

PR bị trả về, chưa chấm, nếu vi phạm một trong các điểm sau:

- Có mật khẩu hoặc DSN trong diff, log hay ảnh chụp.
- Viết cứng schema.table thay vì dùng ref() hoặc source().
- Dùng dbt run.

|**Hạng mục**|**Điểm**|
| :- | :- |
|Phần A|40|
|B1|20|
|B2|10|
|B3|15|
|Phần C|15|
|**Tổng**|**100**|

**Ngưỡng đạt:** \_\_\_\_ / 100
