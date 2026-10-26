# Thực nghiệm transaction và phục hồi dữ liệu kế toán trên PostgreSQL

Bộ demo kiểm tra giao dịch thành công, lỗi giữa chừng, hủy một phần bằng SAVEPOINT, hai phiên cùng sửa dữ liệu và phục hồi sau khi máy chủ bị ngắt bất thường. Dữ liệu sử dụng gồm chứng từ, chi tiết chứng từ và sổ cái; yêu cầu nhất quán là tổng Nợ bằng tổng Có.

README này gộp hướng dẫn chạy transaction, hướng dẫn sự cố và cách hoạt động của các nút điều khiển. Mỗi tình huống có thể chạy lại, không cần tự đổi mã chứng từ.

## 1. Các file chính

```text
.
├── README.md
├── 05_demo_pgadmin.sql
└── su_co/
    ├── du_lieu_goc/
    │   ├── 01_tao_bang.sql
    │   ├── 02_rang_buoc_trigger_thu_tuc.sql
    │   ├── 03_du_lieu_mau.sql
│   └── 04_kiem_thu.sql
    ├── sql_ho_tro/
    │   ├── chuan_bi.sql
    │   └── kiem_tra.sql
    ├── 06_demo_su_co_pgadmin.sql
    ├── 01_CHUAN_BI_VA_MO.cmd
    ├── 02_GAY_SU_CO.cmd
    ├── 03_KHOI_DONG_LAI.cmd
    ├── 04_LUU_KET_QUA.cmd
    ├── 05_TAT_SAU_DEMO.cmd
    ├── 06_XEM_LOG.cmd
    ├── DEMO_MOT_NUT.cmd
    ├── 07_dieu_khien.ps1
    ├── 08_demo_mot_nut.ps1
    ├── KET_QUA_THUC_NGHIEM.md
    └── ket_qua/
```

Thư mục `su_co/may_chu_thu_nghiem/` được tạo khi chạy lần đầu, chứa dữ liệu máy chủ thử nghiệm. Không cần đưa thư mục này lên Git.

## 2. Môi trường cần có

- Windows và pgAdmin 4.
- PostgreSQL 18. Bộ điều khiển sự cố đang dùng cố định thư mục `C:\Program Files\PostgreSQL\18\bin`.
- Cổng `55490` còn trống khi tạo máy chủ thử nghiệm sự cố.

pgAdmin là công cụ nhập SQL và xem kết quả. PostgreSQL là máy chủ thực thi các giao dịch và phục hồi dữ liệu.

Hai phần demo sử dụng hai môi trường:

| Nội dung | Database | Kết nối |
|---|---|---|
| COMMIT, ROLLBACK, SAVEPOINT, hai phiên cạnh tranh | `ketoan_demo_task4` | Server PostgreSQL đã cài và cấu hình trong pgAdmin |
| Ngắt máy chủ và phục hồi | `ketoan_demo_crash` | Server riêng `DEMO_SU_CO`, host `127.0.0.1`, cổng `55490` |

Máy chủ sự cố có thư mục dữ liệu và tiến trình riêng. Tạo thêm một database trên server cũ không đủ để tách riêng việc ngắt tiến trình.

## 3. Chuẩn bị demo transaction lần đầu

1. Trong pgAdmin, kết nối server PostgreSQL.
2. Chuột phải **Databases → Create → Database**, đặt tên `ketoan_demo_task4`.
3. Chuột phải database mới → **Query Tool**.
4. Mở và chạy toàn bộ từng file theo thứ tự, đợi thành công rồi chuyển file tiếp theo:

| Thứ tự | File | Nội dung |
|---|---|---|
| 1 | [01_tao_bang.sql](su_co/du_lieu_goc/01_tao_bang.sql) | Tạo bảng và các ràng buộc cấu trúc |
| 2 | [02_rang_buoc_trigger_thu_tuc.sql](su_co/du_lieu_goc/02_rang_buoc_trigger_thu_tuc.sql) | Tạo trigger, thủ tục ghi sổ và view kiểm tra |
| 3 | [03_du_lieu_mau.sql](su_co/du_lieu_goc/03_du_lieu_mau.sql) | Nạp dữ liệu kế toán giả lập |

Có thể chạy [04_kiem_thu.sql](su_co/du_lieu_goc/04_kiem_thu.sql) một lần sau file 03 để kiểm tra các ràng buộc. File này không bắt buộc để chạy file 05. Với các bài kiểm thử cố tình nhập sai, hệ thống chặn được lỗi thì kết quả kiểm thử vẫn là PASS.

**File 01 có lệnh DROP TABLE. Chỉ chạy trên database demo mới hoặc database có thể dựng lại.** Không chạy lại file này chỉ để lặp một tình huống.

Các lệnh `\c`, `\i` ghi trong phần hướng dẫn của script dành cho psql. Trong pgAdmin, dùng chức năng mở file SQL rồi thực thi nội dung.

## 4. Chạy COMMIT, ROLLBACK và SAVEPOINT

Mở [05_demo_pgadmin.sql](05_demo_pgadmin.sql) trong Query Tool của `ketoan_demo_task4`.

1. Trong menu Execute, bật **Auto commit** và tắt **Auto rollback on error**. Script dùng BEGIN để mở giao dịch rõ ràng; tắt tự rollback để có thể trình diễn bước ROLLBACK bằng tay.
2. Bôi đen **khối 0** rồi nhấn **F5** để kiểm tra kết nối và tạo bộ đánh số. Khối này chạy lại được, không đặt lại số đã dùng.
3. Kiểm tra kỳ `2026-M03` có trạng thái `OPEN`. Script dùng ngày tháng 3/2026 theo dữ liệu mẫu, không dùng ngày hiện tại.
4. Bôi đen và chạy từng khối theo bảng dưới. **Không chạy toàn bộ file 05 cùng lúc.**

| Tình huống | Thứ tự chạy | Kết quả mong đợi |
|---|---|---|
| COMMIT | `1A → 1B` | Chứng từ đã ghi sổ; tổng Nợ = tổng Có = 100.000 |
| Lỗi giữa chừng và ROLLBACK | `2A → 2B → 2C` | 2A thêm dữ liệu hợp lệ; 2B cố tình nhập số tiền 0 và bị chặn; sau 2C không còn chứng từ vừa tạo |
| SAVEPOINT | `3A → 3B → 3C` | Trước khi hủy phần nhập nhầm, tổng tiền là 1.000.000; sau đó chỉ giữ dòng 100.000 và COMMIT |
| Kiểm tra nhất quán | Khối `5` | View `v_chung_tu_lech` trả về 0 dòng |

Với tình huống ROLLBACK, chạy riêng 2B và chụp thông báo lỗi `ck_sotien`, sau đó mới chạy riêng 2C. Đây là lỗi được tạo có chủ đích.

Trong tình huống SAVEPOINT, dòng 900.000 ở 3B là một khoản nhập nhầm nhưng vẫn hợp lệ về ràng buộc. `ROLLBACK TO SAVEPOINT` loại bỏ khoản này, giữ phần đúng trước mốc.

## 5. Demo hai phiên cùng sửa

Phần này nằm trong các khối 4 của file 05. Tên gọi “demo 4” ở đây là tình huống cạnh tranh, không phải file `04_kiem_thu.sql` của nhóm.

### Mở hai kết nối

1. Chuột phải `ketoan_demo_task4` → **Query Tool**, gọi tab này là **A**.
2. Chuột phải chính database đó → **Query Tool** lần nữa, gọi tab mới là **B**.
3. Trong mỗi tab, chạy:

```sql
SELECT current_database() AS ten_database,
       pg_backend_pid() AS pid;
```

Tên database phải giống nhau, PID phải khác nhau. PID là số PostgreSQL tự cấp cho phiên kết nối; không cần tự đặt hoặc sửa số này.

### Thứ tự thao tác

| Bước | Tab | Khối cần chạy | Điều cần thấy |
|---|---|---|---|
| 1 | A | `4-SETUP` | Tạo chứng từ nháp `DEMO4-LOCK` nếu chưa có; chạy lại cũng được |
| 2 | A | `4A` | A sửa chứng từ nhưng chưa COMMIT, giữ khóa trên dòng |
| 3 | B | `4B` | B sửa cùng chứng từ và phải chờ A |
| 4 | A | `4C` | A COMMIT, giải phóng khóa để B tiếp tục |
| 5 | B | `4D` | B COMMIT; lý do cuối cùng là `Phien B sua` |

Khối 4B đặt thời gian chờ khóa tối đa 120 giây. Sau khi B bắt đầu chờ, chuyển về A và chạy 4C trong khoảng này. Nếu bị timeout, ROLLBACK tại B, kết thúc giao dịch còn mở tại A rồi bắt đầu lại từ 4A.

Tình huống này minh họa việc chờ khóa dòng. Giá trị cuối cùng do B ghi sau A; demo không chứng minh hệ thống tự ngăn mọi trường hợp ghi đè nghiệp vụ.

## 6. Chạy lại transaction và mở vào hôm khác

Không cần đổi mã chứng từ bằng tay. File 05 dùng bộ đánh số riêng cho từng loại demo:

- COMMIT: `D4-C-...`, mỗi lần chạy lại từ 1A sẽ tạo mã mới.
- ROLLBACK: `D4-R-...`, chạy lại từ 2A.
- SAVEPOINT: `D4-S-...`, chạy lại từ 3A.
- Hai phiên: dùng lại `DEMO4-LOCK`, lặp `4A → 4B → 4C → 4D`.

Giữ nguyên một tab/kết nối trong toàn bộ các khối của COMMIT, ROLLBACK hoặc SAVEPOINT. Nếu đóng tab hoặc mất kết nối, bắt đầu lại từ đầu tình huống tương ứng.

Khi mở pgAdmin vào hôm khác:

1. Kết nối lại server và database `ketoan_demo_task4`.
2. Mở Query Tool và file 05, kiểm tra lại tùy chọn Auto commit và Auto rollback.
3. Chạy khối 0, sau đó chọn tình huống muốn trình diễn.

Không chạy lại file 01–04 chỉ để lặp demo. Dữ liệu đã COMMIT vẫn được lưu. Nếu bỏ dở một giao dịch, chạy riêng `ROLLBACK;` ở tab đó trước khi bắt đầu lại. Với demo hai phiên, kiểm tra cả A và B.

## 7. Chuẩn bị máy chủ sự cố lần đầu

1. Mở thư mục `su_co` bằng File Explorer của Windows.
2. Nhấp đúp [01_CHUAN_BI_VA_MO.cmd](su_co/01_CHUAN_BI_VA_MO.cmd), đợi hiện **SAN SANG**.
3. Trong pgAdmin, chuột phải **Servers → Register → Server**.
4. Tab **General**, nhập Name là `DEMO_SU_CO`.
5. Tab **Connection**, nhập:

| Ô | Giá trị |
|---|---|
| Host name/address | `127.0.0.1` |
| Port | `55490` |
| Maintenance database | `ketoan_demo_crash` |
| Username | `demo_crash` |
| Password | Để trống |

6. Bấm Save. Mở **DEMO_SU_CO → Databases → ketoan_demo_crash → Query Tool**.
7. Mở [06_demo_su_co_pgadmin.sql](su_co/06_demo_su_co_pgadmin.sql). Bật Auto commit, tắt Auto rollback on error.

Nút chuẩn bị tự tạo máy chủ riêng và nạp bản sao file 01–03. Không cần nạp lại bằng tay. Chạy lại nút này sẽ mở lại máy chủ và giữ dữ liệu đã có.

Máy chủ chỉ lắng nghe trên `127.0.0.1`. Tài khoản không mật khẩu và cấu hình hiện tại chỉ dành cho dữ liệu giả lập trong môi trường thử nghiệm cục bộ.

## 8. Demo sự cố bằng một nút

| Bước | Thao tác | Kết quả mong đợi |
|---|---|---|
| 1 | Trong pgAdmin, chạy riêng khối `6A` | Tạo chứng từ `DA_COMMIT` trị giá 100.000 và COMMIT |
| 2 | Trong chính tab đó, chạy riêng khối `6B` | Tạo chứng từ `CHUA_COMMIT` trị giá 200.000; chưa kết thúc giao dịch |
| 3 | Chụp bảng kết quả ở 6B | Trong phiên này thấy cả hai chứng từ |
| 4 | Trong File Explorer, nhấp đúp [DEMO_MOT_NUT.cmd](su_co/DEMO_MOT_NUT.cmd) | Tự ngắt máy chủ → khởi động lại → kiểm tra và lưu kết quả |
| 5 | Xem và chụp bảng trong cửa sổ điều khiển | `DA_COMMIT` còn; `CHUA_COMMIT` không còn; kiểm tra PASS |
| 6 | Nếu cần xem trong pgAdmin, mở Query Tool mới cùng server/database và chạy riêng `6C` | Xem lại dữ liệu sau phục hồi và kiểm tra nhất quán |

**Sau 6B, giữ nguyên tab, không bấm COMMIT, ROLLBACK hoặc đóng kết nối trước khi gây sự cố.** Nút gây sự cố kiểm tra có giao dịch đang mở; nếu chưa chạy 6B hoặc đã kết thúc giao dịch, nó sẽ dừng và nhắc.

Sau khi khởi động lại, không chạy lại 6A hoặc 6B trước khi xem 6C. Mã lượt demo đã được lưu trong database nên Query Tool mới vẫn tìm được đúng lượt.

### Kết quả mong đợi sau phục hồi

| Loại | Số chứng từ | Số chi tiết | Số dòng sổ cái | Tổng Nợ | Tổng Có |
|---|---:|---:|---:|---:|---:|
| DA_COMMIT | 1 | 1 | 2 | 100.000 | 100.000 |
| CHUA_COMMIT | 0 | 0 | 0 | 0 | 0 |

View `v_chung_tu_lech` phải trả về 0 dòng. Dòng CHUA_COMMIT bằng 0 cho thấy không còn chứng từ, chi tiết hay sổ cái dở dang có thể truy vấn được sau phục hồi.

PostgreSQL tự thực hiện phục hồi khi khởi động. Script điều khiển việc ngắt/khởi động, truy vấn dữ liệu và kiểm tra log; script không tự cài đặt thuật toán phục hồi.

## 9. Sáu nút điều khiển làm gì

Các “nút” là file `.cmd`, gọi PowerShell để chạy [07_dieu_khien.ps1](su_co/07_dieu_khien.ps1) với một giá trị `-Action`.

| File | Action | Công việc thực hiện |
|---|---|---|
| [01_CHUAN_BI_VA_MO.cmd](su_co/01_CHUAN_BI_VA_MO.cmd) | `Setup` | Dùng initdb tạo môi trường riêng nếu chưa có, mở máy chủ, tạo database và nạp dữ liệu mẫu |
| [02_GAY_SU_CO.cmd](su_co/02_GAY_SU_CO.cmd) | `Crash` | Kiểm tra giao dịch đang mở rồi gọi `pg_ctl stop -m immediate` |
| [03_KHOI_DONG_LAI.cmd](su_co/03_KHOI_DONG_LAI.cmd) | `Start` | Gọi `pg_ctl start`, chờ máy chủ sẵn sàng |
| [04_LUU_KET_QUA.cmd](su_co/04_LUU_KET_QUA.cmd) | `Verify` | Truy vấn dữ liệu, kiểm tra WAL recovery và xuất bảng CSV, log, kết quả kiểm tra |
| [05_TAT_SAU_DEMO.cmd](su_co/05_TAT_SAU_DEMO.cmd) | `Stop` | Gọi `pg_ctl stop -m fast` để tắt máy chủ thử nghiệm theo quy trình bình thường |
| [06_XEM_LOG.cmd](su_co/06_XEM_LOG.cmd) | `Logs` | Đọc log và lọc các dòng về sự cố, REDO, trạng thái sẵn sàng |

[DEMO_MOT_NUT.cmd](su_co/DEMO_MOT_NUT.cmd) gọi [08_demo_mot_nut.ps1](su_co/08_demo_mot_nut.ps1), thực hiện lần lượt **Crash → Start → Verify**. Nếu muốn tách từng bước để giải thích, có thể dùng riêng các nút 02, 03, 04; sau khởi động lại mở Query Tool mới chạy 6C.

Nút 02 dừng bằng chế độ immediate, khiến lần khởi động sau cần crash recovery. Nút 05 dùng fast: kết thúc các giao dịch đang mở rồi tắt sạch. Đóng pgAdmin hoặc tắt máy chủ bình thường không thay thế tình huống ngắt bất thường này. Đây là mô phỏng tiến trình dừng bất thường, không phải kiểm thử cắt điện phần cứng.

## 10. Tự tạo một nút bằng Notepad

Có thể bắt đầu bằng nút xem log vì nút này chỉ đọc thông tin.

1. Mở Notepad, tạo file mới.
2. Nhập nội dung sau:

```bat
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp007_dieu_khien.ps1" -Action Logs
pause
```

3. Chọn **File → Save As**.
4. Chọn **Save as type: All files**, đặt tên `THU_XEM_LOG.cmd`.
5. Lưu vào thư mục `su_co`, cùng cấp với `07_dieu_khien.ps1`. Tên file phải kết thúc bằng `.cmd`, không phải `.cmd.txt`.
6. Sau khi đã chạy nút chuẩn bị, nhấp đúp file mới để xem các dòng log.

### Giải thích từng thành phần

| Thành phần | Ý nghĩa |
|---|---|
| `@echo off` | Ẩn việc in lại câu lệnh, vẫn hiển thị kết quả và thông báo |
| `powershell.exe` | Mở Windows PowerShell để chạy script |
| `-NoProfile` | Không nạp cấu hình PowerShell cá nhân |
| `-ExecutionPolicy Bypass` | Đặt chính sách thực thi cho tiến trình PowerShell được mở ở lần chạy này, không sửa chính sách lưu lâu dài của máy |
| `-File` | Chỉ định file PowerShell cần chạy |
| `%~dp0` | Thư mục chứa chính file `.cmd`; ghép với tên script để tìm đúng file bên cạnh |
| Dấu ngoặc kép quanh đường dẫn | Giữ đường dẫn có dấu cách thành một đối số |
| `-Action Logs` | Truyền yêu cầu xem log cho script điều khiển |
| `pause` | Giữ cửa sổ mở, đợi nhấn phím để có thời gian đọc kết quả |

Giữ nguyên `%~dp007_dieu_khien.ps1`: phần `%~dp0` được ghép trực tiếp với tên `07_dieu_khien.ps1`, không thêm khoảng trắng vào giữa.

Để tự tạo đủ sáu nút, tạo sáu file `.cmd` với cùng mẫu trên, đổi giá trị sau `-Action` theo bảng ở mục 9. Việc đổi Action chỉ chọn thao tác; toàn bộ xử lý vẫn nằm trong file PowerShell. Các file `.cmd` không thay thế được `07_dieu_khien.ps1`, các file SQL hỗ trợ và dữ liệu mẫu đi kèm.

## 11. Chạy lại demo sự cố

- Trong cùng buổi: chạy lại từ `6A → 6B`, sau đó nhấp đúp `DEMO_MOT_NUT.cmd`. Mỗi lượt tự tạo mã mới.
- Hôm khác: chạy `01_CHUAN_BI_VA_MO.cmd`, kết nối lại DEMO_SU_CO trong pgAdmin, mở file 06 rồi bắt đầu từ 6A.
- Số tự động có thể nhảy sau ROLLBACK hoặc crash, ví dụ từ 1 lên 34. Không cần sửa thành số liên tiếp.
- Khi xong: chạy `05_TAT_SAU_DEMO.cmd` để tắt riêng máy chủ thử nghiệm. Dữ liệu và kết quả đã lưu vẫn được giữ.
- Nếu chỉ cần xem minh chứng cũ, mở các file trong `su_co/ket_qua/`.

## 12. Kết quả thực nghiệm và phân tích lý thuyết

Phải ghi rõ loại thông tin khi đưa vào báo cáo:

| Loại | Ví dụ |
|---|---|
| Lý thuyết hoặc kết quả mong đợi | Giao dịch đã COMMIT cần được giữ sau sự cố; giao dịch chưa COMMIT không được để lại dữ liệu có hiệu lực dở dang |
| Kết quả chạy thực tế | Mã chứng từ, số dòng trước/sau, thông báo PASS/FAIL, log REDO và thời gian đo được ở một lượt cụ thể |

Bộ mã đã được kiểm tra trên PostgreSQL 18:

- COMMIT, ROLLBACK, SAVEPOINT và bước chuẩn bị hai phiên đã được kiểm tra chạy lặp ba lượt.
- Demo sự cố có hai lượt kiểm tra tách bước và một lượt kiểm tra cách một nút; các lượt này thực thi SQL bằng psql, không phải ảnh chụp pgAdmin.
- Kết quả và mốc thời gian cụ thể nằm trong [KET_QUA_THUC_NGHIEM.md](su_co/KET_QUA_THUC_NGHIEM.md), cùng các file trong [ket_qua](su_co/ket_qua/).

Khi tự trình diễn bằng pgAdmin, cần lưu ảnh và kết quả của chính lượt đó. Không ghi rằng đã đo hoặc đã chụp giao diện nếu chưa thực hiện.

### Các file được lưu sau demo sự cố

| File | Nội dung |
|---|---|
| `sau_phuc_hoi.csv` | Bảng dữ liệu thực tế sau phục hồi |
| `log_su_co_va_phuc_hoi.txt` | Log từ lúc yêu cầu ngắt đến khi kiểm tra |
| `kiem_tra.txt` | Kết luận kiểm tra dữ liệu |
| `thong_tin_su_co.json` | Mã lượt, thời điểm gây sự cố |
| `thoi_gian_khoi_dong.json` | Thời gian từ lúc gọi khởi động đến khi máy chủ báo sẵn sàng |

Thời gian chờ của lệnh khởi động không phải thời gian riêng của WAL replay và không đại diện cho toàn bộ RTO của doanh nghiệp. Hai lượt kiểm tra ban đầu còn lưu `truoc_su_co.txt` và `phien_bi_ngat.txt` từ phiên psql.

Khi chạy trong pgAdmin, cần chụp bảng ở 6B trước khi ngắt: dữ liệu chưa COMMIT chỉ hiện trong phiên giao dịch đó. Có thể nhấp `06_XEM_LOG.cmd` để xem các dòng `automatic recovery in progress`, `redo starts at`, `redo done at` và `ready to accept connections`.

## 13. Xử lý lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Khối 2B báo lỗi số tiền | Đúng kịch bản; chụp thông báo rồi chạy riêng 2C |
| Báo giao dịch đang ở trạng thái lỗi | Chạy riêng `ROLLBACK;`, kiểm tra lỗi trước đó rồi bắt đầu lại tình huống |
| Báo currval chưa được xác định | Đang dùng tab/kết nối mới hoặc bỏ qua khối đầu; chạy lại từ 1A, 2A hoặc 3A tương ứng |
| B chờ quá lâu trong demo hai phiên | Chạy 4C tại A; nếu đã timeout thì kết thúc giao dịch còn mở và làm lại |
| Cổng 55490 đang được dùng | Kiểm tra server demo đã mở ở thư mục khác hay chưa; không dừng tùy tiện một server khác để lấy cổng |
| Nút gây sự cố báo chưa có giao dịch dang dở | Chạy 6B và giữ tab mở, chưa COMMIT/ROLLBACK |
| pgAdmin mất kết nối sau sự cố | Khởi động lại server demo, mở Query Tool mới cùng database rồi chạy 6C |
| Không tìm thấy PowerShell script | Giữ các file `.cmd` cùng thư mục với các file `.ps1` đi kèm |

Nếu gặp lỗi ngoài tình huống cố ý, lưu thông báo và xử lý trước khi tiếp tục. Không dùng Task Manager để kết thúc toàn bộ tiến trình PostgreSQL trên máy.

## 14. Đưa bộ demo lên Git

Đặt README ở gốc bộ demo, cùng cấp với `05_demo_pgadmin.sql` và thư mục `su_co`. Giữ cấu trúc này để các liên kết tương đối hoạt động khi xem trên GitHub.

Đưa lên Git các file SQL, CMD, PowerShell, README và minh chứng thực nghiệm đã chọn. Không đưa dữ liệu máy chủ đang chạy hoặc thư mục kiểm tra tạm lên Git. Có thể thêm vào `.gitignore` ở cùng cấp README:

```gitignore
/.verification/
/su_co/may_chu_thu_nghiem/
/06_demo_su_co.zip
```

Không bỏ qua toàn bộ `*.txt`, `*.csv` hoặc `*.json`, vì các định dạng này cũng được dùng để lưu minh chứng thực nghiệm trong `su_co/ket_qua/`.

## 15. Tài liệu tham khảo

- [pgAdmin Query Tool và tùy chọn thực thi](https://www.pgadmin.org/docs/pgadmin4/latest/query_tool_toolbar.html)
- [PostgreSQL SAVEPOINT](https://www.postgresql.org/docs/current/sql-savepoint.html)
- [PostgreSQL sequence](https://www.postgresql.org/docs/current/functions-sequence.html)
- [Điều khiển máy chủ bằng pg_ctl](https://www.postgresql.org/docs/18/app-pg-ctl.html)
- [Các chế độ dừng máy chủ PostgreSQL](https://www.postgresql.org/docs/18/server-shutdown.html)
- [Windows pause](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/pause)
- [PowerShell execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1)
