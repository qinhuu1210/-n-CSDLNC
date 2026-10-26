# Kết quả kiểm tra demo sự cố

Đã chạy hai lượt ngắt bất thường và phục hồi trên PostgreSQL 18, ngày 24/10/2026, trong instance riêng cổng 55490. Hai lượt dùng đúng các khối SQL 6A, 6B, 6C và bộ điều khiển đi kèm. Phiên thực thi kiểm tra dùng psql; thao tác tương ứng trong pgAdmin được mô tả trong hướng dẫn.

Trong mỗi lượt, đã kiểm tra phiên thứ hai có giao dịch đang mở và đã ghi dữ liệu trước khi ngắt. Bộ điều khiển dừng bằng chế độ immediate, khởi động lại rồi kiểm tra cả dữ liệu và log WAL recovery.

## Bảng kết quả thực tế

| Lượt kiểm tra | Mã chứng từ | Trước sự cố trong phiên đang mở | Sau phục hồi | Kết quả |
|---|---|---|---|---|
| 1 | D4-OK-1 | Đã COMMIT; 1 chứng từ, 1 chi tiết, 2 dòng sổ cái; Nợ = Có = 100.000 | Giữ nguyên | Đạt |
| 1 | D4-OPEN-1 | Chưa COMMIT; 1 chứng từ, 1 chi tiết, 2 dòng sổ cái; Nợ = Có = 200.000 | 0 chứng từ, 0 chi tiết, 0 dòng sổ cái | Đạt |
| 2 | D4-OK-34 | Đã COMMIT; 1 chứng từ, 1 chi tiết, 2 dòng sổ cái; Nợ = Có = 100.000 | Giữ nguyên | Đạt |
| 2 | D4-OPEN-34 | Chưa COMMIT; 1 chứng từ, 1 chi tiết, 2 dòng sổ cái; Nợ = Có = 200.000 | 0 chứng từ, 0 chi tiết, 0 dòng sổ cái | Đạt |

Cả hai lượt, truy vấn v_chung_tu_lech không trả về dòng nào. Mã lượt tăng từ 1 đến 34 là hiện tượng sequence có thể nhảy số sau crash; số thứ tự không được dùng để kết luận mất chứng từ. Đã kiểm tra gọi lại nút chuẩn bị vẫn giữ đủ hai bản ghi lượt demo và các chứng từ đã COMMIT.

## Bằng chứng log

| Lượt | Yêu cầu dừng bất thường | Automatic recovery | REDO bắt đầu | REDO hoàn tất | Sẵn sàng nhận kết nối |
|---|---|---|---|---|---|
| 1 | 23:27:00.706 | 23:27:01.559 | 23:27:01.562 | 23:27:01.567 | 23:27:01.588 |
| 2 | 23:27:02.983 | 23:27:03.769 | 23:27:03.772 | 23:27:03.775 | 23:27:03.797 |

Mốc giờ lấy từ log máy chủ, múi giờ UTC+7. Thời gian chờ của lệnh khởi động được ghi nhận lần lượt 0,405 và 0,406 giây; số này gồm thời gian gọi lệnh và chờ máy chủ sẵn sàng, không phải phép đo riêng tốc độ WAL replay hay RTO đầy đủ của một hệ thống doanh nghiệp.

## Các file minh chứng

Hai thư mục thực nghiệm trong ket_qua:

- lan_1_20261024_232702_067
- lan_34_20261024_232704_278

Mỗi thư mục có bảng CSV sau phục hồi, kết quả kiểm tra, log sự cố và phục hồi, thông tin thời điểm gây sự cố, thời gian khởi động. Hai lượt kiểm tra này còn lưu truoc_su_co.txt và phien_bi_ngat.txt từ phiên thực thi, cho thấy dữ liệu trước sự cố và thông báo kết nối bị ngắt.

Đây là bằng chứng thực thi bằng psql, không phải ảnh chụp pgAdmin. Khi trình bày, bạn chạy lại các khối tương ứng trong pgAdmin và chụp bảng trước/sau để bổ sung minh chứng giao diện.

Sau kiểm tra, server thử nghiệm đã được tắt bình thường. Mở lại bằng 01_CHUAN_BI_VA_MO.cmd khi cần demo; dữ liệu và lịch sử cũ được giữ nguyên.

## Lượt kiểm tra bổ sung đã lưu

Lượt kiểm tra bổ sung được thực hiện bằng bản điều khiển tự động tại thời điểm kiểm thử. Bản bàn giao hiện tại sử dụng các nút riêng 02, 03 và 04 để thực hiện từng bước; dữ liệu minh chứng của lượt cũ được giữ nguyên. Lượt mang mã 67: D4-OK-67 vẫn có 1 chứng từ, 1 chi tiết, 2 dòng sổ cái, Nợ = Có = 100.000; D4-OPEN-67 không còn chứng từ, chi tiết hay sổ cái. Log ghi nhận WAL recovery hoàn tất, kiểm tra trả về PASS. Minh chứng nằm trong ket_qua/lan_67_20261024_233718_360. Đây vẫn là thực nghiệm bằng phiên psql giữ giao dịch mở, chưa phải ảnh chụp giao diện pgAdmin.
