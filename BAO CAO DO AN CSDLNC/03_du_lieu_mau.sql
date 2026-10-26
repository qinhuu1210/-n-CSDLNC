-- =====================================================================
-- FILE 03: DỮ LIỆU MẪU
-- Chạy SAU file 01 và 02:   \i 03_du_lieu_mau.sql
--
-- Thứ tự nạp phải theo thứ tự khóa ngoại: bảng cha trước, bảng con sau:
--   Kỳ, Loại CT, Tài khoản (cha trước con), Đối tượng + 3 bảng con,
--   Chứng từ -> Chi tiết -> CALL sp_post_voucher (ghi sổ).
-- Toàn bộ dữ liệu là dữ liệu giả lập để thử nghiệm.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. KỲ KẾ TOÁN (tháng 1-3/2026). Tạm để cả 3 kỳ OPEN, cuối file sẽ đóng kỳ 1.
-- ---------------------------------------------------------------------
INSERT INTO KY_KE_TOAN (MaKy, TenKy, NgayBatDau, NgayKetThuc, TrangThaiKy) VALUES
('2026-M01', 'Tháng 01/2026', '2026-01-01', '2026-01-31', 'OPEN'),
('2026-M02', 'Tháng 02/2026', '2026-02-01', '2026-02-28', 'OPEN'),
('2026-M03', 'Tháng 03/2026', '2026-03-01', '2026-03-31', 'OPEN');

-- ---------------------------------------------------------------------
-- 2. LOẠI CHỨNG TỪ
-- ---------------------------------------------------------------------
INSERT INTO LOAI_CHUNG_TU (MaLoaiCT, TenLoaiCT, TienTo) VALUES
('PT',  'Phiếu thu',          'PT'),
('PC',  'Phiếu chi',          'PC'),
('HD',  'Hóa đơn bán hàng',   'HD'),
('PN',  'Phiếu nhập kho',     'PN'),
('UNC', 'Ủy nhiệm chi',       'UNC'),
('PKT', 'Phiếu kế toán tổng hợp', 'PKT');

-- ---------------------------------------------------------------------
-- 3. DANH MỤC TÀI KHOẢN (cây phân cấp; PHẢI chèn tài khoản cha trước tài khoản con)
-- Cột: MaTK, TenTK, CapTK, LoaiTK, TinhChat, LaTaiKhoanLa, ConSuDung, TheoDoiCongNo, MaTKMe
-- LaTaiKhoanLa của tài khoản cha sẽ được trigger tự đổi thành FALSE khi chèn tài khoản con.
-- ---------------------------------------------------------------------
INSERT INTO TAI_KHOAN (MaTK, TenTK, CapTK, LoaiTK, TinhChat, LaTaiKhoanLa, ConSuDung, TheoDoiCongNo, MaTKMe) VALUES
-- Nhóm tài sản
('111',   'Tiền mặt',                        1, 'TAI_SAN',       'DU_NO',      TRUE, TRUE,  FALSE, NULL),
('1111',  'Tiền Việt Nam',                   2, 'TAI_SAN',       'DU_NO',      TRUE, TRUE,  FALSE, '111'),
('1112',  'Ngoại tệ (ngừng sử dụng)',        2, 'TAI_SAN',       'DU_NO',      TRUE, FALSE, FALSE, '111'),
('112',   'Tiền gửi ngân hàng',              1, 'TAI_SAN',       'DU_NO',      TRUE, TRUE,  FALSE, NULL),
('1121',  'Tiền Việt Nam gửi ngân hàng',     2, 'TAI_SAN',       'DU_NO',      TRUE, TRUE,  FALSE, '112'),
('131',   'Phải thu của khách hàng',         1, 'TAI_SAN',       'LUONG_TINH', TRUE, TRUE,  TRUE,  NULL),
('133',   'Thuế GTGT được khấu trừ',         1, 'TAI_SAN',       'DU_NO',      TRUE, TRUE,  FALSE, NULL),
('156',   'Hàng hóa',                        1, 'TAI_SAN',       'DU_NO',      TRUE, TRUE,  FALSE, NULL),
-- Nhóm nợ phải trả
('331',   'Phải trả cho người bán',          1, 'NO_PHAI_TRA',   'LUONG_TINH', TRUE, TRUE,  TRUE,  NULL),
('333',   'Thuế và các khoản phải nộp NN',   1, 'NO_PHAI_TRA',   'DU_CO',      TRUE, TRUE,  FALSE, NULL),
('3331',  'Thuế giá trị gia tăng phải nộp',  2, 'NO_PHAI_TRA',   'DU_CO',      TRUE, TRUE,  FALSE, '333'),
('33311', 'Thuế GTGT đầu ra',                3, 'NO_PHAI_TRA',   'DU_CO',      TRUE, TRUE,  FALSE, '3331'),
('334',   'Phải trả người lao động',         1, 'NO_PHAI_TRA',   'DU_CO',      TRUE, TRUE,  TRUE,  NULL),
-- Nhóm vốn chủ sở hữu
('411',   'Vốn đầu tư của chủ sở hữu',       1, 'VON_CHU_SO_HUU','DU_CO',      TRUE, TRUE,  FALSE, NULL),
-- Nhóm doanh thu
('511',   'Doanh thu bán hàng và cung cấp dịch vụ', 1, 'DOANH_THU', 'DU_CO',   TRUE, TRUE,  FALSE, NULL),
('5111',  'Doanh thu bán hàng hóa',          2, 'DOANH_THU',     'DU_CO',      TRUE, TRUE,  FALSE, '511'),
-- Nhóm chi phí
('632',   'Giá vốn hàng bán',                1, 'CHI_PHI',       'DU_NO',      TRUE, TRUE,  FALSE, NULL),
('642',   'Chi phí quản lý doanh nghiệp',    1, 'CHI_PHI',       'DU_NO',      TRUE, TRUE,  FALSE, NULL),
('6421',  'Chi phí nhân viên quản lý',       2, 'CHI_PHI',       'DU_NO',      TRUE, TRUE,  FALSE, '642'),
('6427',  'Chi phí dịch vụ mua ngoài',       2, 'CHI_PHI',       'DU_NO',      TRUE, TRUE,  FALSE, '642');

-- ---------------------------------------------------------------------
-- 4. ĐỐI TƯỢNG (bảng cha) rồi đến 3 bảng con
-- ---------------------------------------------------------------------
INSERT INTO DOI_TUONG (MaDoiTuong, LoaiDoiTuong, TenDoiTuong, DiaChi, MaSoThue, DienThoai, Email) VALUES
('KH001',  'KHACH_HANG',   'Công ty TNHH An Phát',            '12 Lê Lợi, Quận 1, TP.HCM',       '0312345678', '0281234567', 'ketoan@anphat.example'),
('KH002',  'KHACH_HANG',   'Cửa hàng Minh Khoa',              '45 Nguyễn Trãi, Quận 5, TP.HCM',  '0398765432', '0287654321', 'minhkhoa@example.com'),
('NCC001', 'NHA_CUNG_CAP', 'Công ty CP Thiết bị Hòa Bình',    '88 Điện Biên Phủ, Bình Thạnh',    '0301112223', '0289998887', 'sales@hoabinh.example'),
('NCC002', 'NHA_CUNG_CAP', 'Công ty TNHH Văn phòng phẩm Sao Mai', '9 Trần Hưng Đạo, Quận 1',    '0304445556', '0283334445', 'saomai@example.com'),
('NV001',  'NHAN_VIEN',    'Nguyễn Văn An',                   'Thủ Đức, TP.HCM',                 NULL,         '0901000001', 'an.nv@example.com'),
('NV002',  'NHAN_VIEN',    'Lê Thị Hoa',                      'Quận 7, TP.HCM',                  NULL,         '0901000002', 'hoa.lt@example.com');

INSERT INTO KHACH_HANG (MaDoiTuong, HanMucNo, SoNgayDuocNo) VALUES
('KH001', 200000000, 30),
('KH002',  50000000, 15);

INSERT INTO NHA_CUNG_CAP (MaDoiTuong, SoTKNH, TenNganHang) VALUES
('NCC001', '0011001234567', 'Vietcombank'),
('NCC002', '0451000987654', 'BIDV');

INSERT INTO NHAN_VIEN (MaDoiTuong, ChucVu, PhongBan) VALUES
('NV001', 'Kế toán trưởng', 'Phòng Kế toán'),
('NV002', 'Nhân viên bán hàng', 'Phòng Kinh doanh');

-- =====================================================================
-- 5. CHỨNG TỪ THÁNG 01/2026
-- Mỗi chứng từ làm 3 bước: (a) chèn header, (b) chèn các dòng chi tiết, (c) ghi sổ.
-- (TongTien do trigger tự tính, không cần điền; NienDo là cột tự sinh.)
-- =====================================================================

-- CT1: Chủ sở hữu góp vốn (600 triệu = 500 triệu tiền gửi NH + 100 triệu tiền mặt)
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('PKT001/01/26', '2026-01-05', '2026-01-05', 'PKT', '2026-M01', NULL, 'Chủ sở hữu góp vốn điều lệ', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '1121', '411', 500000000, 'Góp vốn bằng chuyển khoản'),
               (2, '1111', '411', 100000000, 'Góp vốn bằng tiền mặt')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'PKT' AND ct.SoCT = 'PKT001/01/26';

CALL sp_post_voucher_by_so('PKT', 'PKT001/01/26');

-- CT2: Nhập kho hàng hóa từ NCC001, chưa trả tiền (80 triệu + VAT 8 triệu)
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('PN001/01/26', '2026-01-12', '2026-01-12', 'PN', '2026-M01', 'NCC001', 'Nhập kho hàng hóa của Hòa Bình, chưa thanh toán', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '156', '331',  80000000, 'Giá trị hàng nhập kho'),
               (2, '133', '331',   8000000, 'Thuế GTGT đầu vào 10%')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'PN' AND ct.SoCT = 'PN001/01/26';

CALL sp_post_voucher_by_so('PN', 'PN001/01/26');

-- CT3: Trả bớt tiền cho NCC001 bằng chuyển khoản (50 triệu)
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('PC001/01/26', '2026-01-20', '2026-01-20', 'PC', '2026-M01', 'NCC001', 'Trả tiền hàng đợt 1 cho Hòa Bình', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '331', '1121', 50000000, 'Chuyển khoản trả nợ NCC')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'PC' AND ct.SoCT = 'PC001/01/26';

CALL sp_post_voucher_by_so('PC', 'PC001/01/26');

-- CT4: Bán hàng cho KH001, chưa thu tiền (30 triệu + VAT 3 triệu), kèm giá vốn 20 triệu
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('HD001/01/26', '2026-01-25', '2026-01-25', 'HD', '2026-M01', 'KH001', 'Bán hàng cho An Phát, chưa thu tiền', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '131', '5111',  30000000, 'Doanh thu bán hàng'),
               (2, '131', '33311',  3000000, 'Thuế GTGT đầu ra 10%'),
               (3, '632', '156',   20000000, 'Giá vốn hàng xuất bán')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'HD' AND ct.SoCT = 'HD001/01/26';

CALL sp_post_voucher_by_so('HD', 'HD001/01/26');

-- Kết thúc tháng 1: ĐÓNG KỲ 2026-M01 (sau bước này không thể lập/ghi sổ chứng từ vào tháng 1 nữa)
UPDATE KY_KE_TOAN SET TrangThaiKy = 'CLOSED' WHERE MaKy = '2026-M01';

-- =====================================================================
-- 6. CHỨNG TỪ THÁNG 02/2026
-- =====================================================================

-- CT5: KH001 thanh toán nợ bằng tiền mặt (20 triệu)
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('PT001/02/26', '2026-02-03', '2026-02-03', 'PT', '2026-M02', 'KH001', 'An Phát thanh toán một phần tiền hàng', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '1111', '131', 20000000, 'Thu tiền mặt của khách hàng')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'PT' AND ct.SoCT = 'PT001/02/26';

CALL sp_post_voucher_by_so('PT', 'PT001/02/26');

-- CT6: Chi tiền mặt mua văn phòng phẩm của NCC002 (2 triệu) - không qua tài khoản công nợ
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('PC001/02/26', '2026-02-10', '2026-02-10', 'PC', '2026-M02', 'NCC002', 'Mua văn phòng phẩm trả tiền mặt', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '6427', '1111', 2000000, 'Chi phí văn phòng phẩm')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'PC' AND ct.SoCT = 'PC001/02/26';

CALL sp_post_voucher_by_so('PC', 'PC001/02/26');

-- CT7: Bán hàng thu tiền mặt ngay cho KH002 (10 triệu + VAT 1 triệu), giá vốn 6 triệu
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('HD001/02/26', '2026-02-14', '2026-02-14', 'HD', '2026-M02', 'KH002', 'Bán hàng thu tiền mặt cho Minh Khoa', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '1111', '5111',  10000000, 'Doanh thu bán hàng thu tiền ngay'),
               (2, '1111', '33311',  1000000, 'Thuế GTGT đầu ra 10%'),
               (3, '632',  '156',    6000000, 'Giá vốn hàng xuất bán')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'HD' AND ct.SoCT = 'HD001/02/26';

CALL sp_post_voucher_by_so('HD', 'HD001/02/26');

-- CT8: Tính lương tháng 2 cho NV001 (15 triệu) - tài khoản 334 là công nợ nên cần MaDoiTuong
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('PKT001/02/26', '2026-02-28', '2026-02-28', 'PKT', '2026-M02', 'NV001', 'Tính lương tháng 02/2026', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '6421', '334', 15000000, 'Lương nhân viên quản lý')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'PKT' AND ct.SoCT = 'PKT001/02/26';

CALL sp_post_voucher_by_so('PKT', 'PKT001/02/26');

-- =====================================================================
-- 7. CHỨNG TỪ THÁNG 03/2026
-- =====================================================================

-- CT9: Trả lương tháng 2 cho NV001 bằng tiền mặt (15 triệu)
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
VALUES ('PC001/03/26', '2026-03-05', '2026-03-05', 'PC', '2026-M03', 'NV001', 'Trả lương tháng 02/2026', 'ketoan01');

INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
SELECT ct.MaCT, v.stt, v.tkno, v.tkco, v.tien, v.dg
  FROM CHUNG_TU ct,
       (VALUES (1, '334', '1111', 15000000, 'Chi tiền mặt trả lương')) AS v(stt, tkno, tkco, tien, dg)
 WHERE ct.MaLoaiCT = 'PC' AND ct.SoCT = 'PC001/03/26';

CALL sp_post_voucher_by_so('PC', 'PC001/03/26');

-- =====================================================================
-- 8. KIỂM TRA NHANH SAU KHI NẠP
-- =====================================================================
SELECT 'KY_KE_TOAN' AS bang, COUNT(*) AS so_dong FROM KY_KE_TOAN
UNION ALL SELECT 'TAI_KHOAN',        COUNT(*) FROM TAI_KHOAN
UNION ALL SELECT 'DOI_TUONG',        COUNT(*) FROM DOI_TUONG
UNION ALL SELECT 'CHUNG_TU',         COUNT(*) FROM CHUNG_TU
UNION ALL SELECT 'CHI_TIET_CHUNG_TU',COUNT(*) FROM CHI_TIET_CHUNG_TU
UNION ALL SELECT 'SO_CAI',           COUNT(*) FROM SO_CAI;
