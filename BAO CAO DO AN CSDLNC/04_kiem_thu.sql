-- =====================================================================
-- FILE 04: BỘ KIỂM THỬ TÍNH NHẤT QUÁN (Rule 1 -> Rule 6)
-- Chạy SAU file 01, 02, 03:   \i 04_kiem_thu.sql
--
-- Cách hoạt động: mỗi test là một khối DO ... END.
--   * Test "phải bị chặn": cố tình làm sai. Nếu CSDL báo lỗi -> ghi PASS kèm nội dung lỗi.
--     Nếu CSDL KHÔNG báo lỗi -> ghi FAIL (ràng buộc chưa hoạt động).
--     Khi có lỗi, mọi thay đổi trong khối đó tự động bị ROLLBACK.
--   * Test "phải thành công": làm đúng. Nếu chạy được -> PASS.
-- Kết quả tổng hợp ở bảng ket_qua_test (xem cuối file).
-- =====================================================================

DROP TABLE IF EXISTS ket_qua_test;
CREATE TEMP TABLE ket_qua_test (
    ma_test   VARCHAR(10),
    rule_ap   VARCHAR(20),
    mo_ta     VARCHAR(200),
    ket_qua   VARCHAR(5),
    thong_bao TEXT
);

-- Hàm phụ (chỉ tồn tại trong phiên làm việc này): tạo nhanh 1 chứng từ nháp, trả về MaCT
CREATE OR REPLACE FUNCTION pg_temp.tao_nhap(
    p_so VARCHAR, p_loai VARCHAR, p_ngay DATE, p_ky VARCHAR, p_dt VARCHAR
) RETURNS BIGINT AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap)
    VALUES (p_so, p_ngay, p_ngay, p_loai, p_ky, p_dt, 'Chứng từ kiểm thử', 'tester')
    RETURNING MaCT INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- NHÓM 0: CHỨNG TỪ HỢP LỆ (phải thành công)
-- =====================================================================

-- V01: Chứng từ nhiều dòng, hợp lệ, ghi sổ thành công và sổ cái cân Nợ = Có
DO $$
DECLARE
    v_id BIGINT; v_no NUMERIC; v_co NUMERIC; v_da BOOLEAN; v_tong NUMERIC;
BEGIN
    v_id := pg_temp.tao_nhap('PT001/03/26', 'PT', '2026-03-11', '2026-M03', 'KH001');
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai) VALUES
        (v_id, 1, '1121', '131', 10000000, 'Thu chuyển khoản'),
        (v_id, 2, '1111', '131',  5000000, 'Thu tiền mặt');
    CALL sp_post_voucher(v_id);

    SELECT DaGhiSo, TongTien INTO v_da, v_tong FROM CHUNG_TU WHERE MaCT = v_id;
    SELECT SUM(SoTienNo), SUM(SoTienCo) INTO v_no, v_co FROM SO_CAI WHERE MaCT = v_id;

    IF v_da AND v_no = v_co AND v_no = 15000000 AND v_tong = 15000000 THEN
        INSERT INTO ket_qua_test VALUES ('V01', 'Rule 1', 'Chứng từ hợp lệ 2 dòng ghi sổ thành công, sổ cái cân Nợ=Có',
                                         'PASS', 'Tổng Nợ = ' || v_no || ', tổng Có = ' || v_co);
    ELSE
        INSERT INTO ket_qua_test VALUES ('V01', 'Rule 1', 'Chứng từ hợp lệ 2 dòng ghi sổ thành công, sổ cái cân Nợ=Có',
                                         'FAIL', 'Số liệu không khớp');
    END IF;
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('V01', 'Rule 1', 'Chứng từ hợp lệ 2 dòng ghi sổ thành công, sổ cái cân Nợ=Có', 'FAIL', SQLERRM);
END $$;

-- V02: Rule 5 - cùng SoCT nhưng KHÁC loại chứng từ thì được phép
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('PC001/03/26', 'PT', '2026-03-12', '2026-M03', NULL);   -- 'PC001/03/26' đã có ở loại PC
    DELETE FROM CHUNG_TU WHERE MaCT = v_id;                                          -- dọn dẹp (chứng từ nháp xóa được)
    INSERT INTO ket_qua_test VALUES ('V02', 'Rule 5', 'Cùng SoCT, khác loại chứng từ -> được phép', 'PASS', 'Không có lỗi, đúng kỳ vọng');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('V02', 'Rule 5', 'Cùng SoCT, khác loại chứng từ -> được phép', 'FAIL', SQLERRM);
END $$;

-- =====================================================================
-- NHÓM 1: RULE 1 - CÂN ĐỐI NỢ - CÓ
-- =====================================================================

-- T01: Ghi sổ chứng từ không có dòng chi tiết nào
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T01', 'PKT', '2026-03-13', '2026-M03', NULL);
    CALL sp_post_voucher(v_id);
    INSERT INTO ket_qua_test VALUES ('T01', 'Rule 1', 'Ghi sổ chứng từ rỗng (không có dòng) phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T01', 'Rule 1', 'Ghi sổ chứng từ rỗng (không có dòng) phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T02: Header TongTien bị sửa tay cho lệch với tổng các dòng chi tiết
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T02', 'PKT', '2026-03-13', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '1111', '411', 1000000);
    UPDATE CHUNG_TU SET TongTien = 999 WHERE MaCT = v_id;        -- cố tình làm lệch
    CALL sp_post_voucher(v_id);
    INSERT INTO ket_qua_test VALUES ('T02', 'Rule 1', 'TongTien header lệch tổng chi tiết phải bị chặn khi ghi sổ', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T02', 'Rule 1', 'TongTien header lệch tổng chi tiết phải bị chặn khi ghi sổ', 'PASS', SQLERRM);
END $$;

-- T03: Ghi sổ cái lệch (chỉ bên Nợ, thiếu bên Có) -> deferred constraint trigger chặn lúc COMMIT.
-- Ta giả lập "thủ tục ghi sổ bị lỗi" bằng cách tự bật cờ rồi INSERT lệch.
-- SET CONSTRAINTS ... IMMEDIATE ép trigger chạy ngay (thay cho COMMIT) để bắt lỗi trong khối DO.
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T03', 'PKT', '2026-03-13', '2026-M03', NULL);
    PERFORM set_config('app.dang_ghi_so', 'on', true);
    INSERT INTO SO_CAI (MaKy, MaCT, NgayGhiSo, MaTK, SoTienNo, SoTienCo)
    VALUES ('2026-M03', v_id, '2026-03-13', '1111', 1000000, 0);       -- chỉ có Nợ, thiếu Có
    SET CONSTRAINTS trg_socai_can_doi IMMEDIATE;                       -- kiểm tra ngay
    INSERT INTO ket_qua_test VALUES ('T03', 'Rule 1', 'Sổ cái lệch Nợ/Có bị deferred trigger chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T03', 'Rule 1', 'Sổ cái lệch Nợ/Có bị deferred trigger chặn', 'PASS', SQLERRM);
END $$;

-- T04: Không cho INSERT thẳng vào SO_CAI (phải đi qua sp_post_voucher)
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T04', 'PKT', '2026-03-13', '2026-M03', NULL);
    INSERT INTO SO_CAI (MaKy, MaCT, NgayGhiSo, MaTK, SoTienNo, SoTienCo)
    VALUES ('2026-M03', v_id, '2026-03-13', '1111', 1000000, 0);
    INSERT INTO ket_qua_test VALUES ('T04', 'Rule 1/3', 'INSERT thẳng vào SO_CAI (không qua thủ tục) phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T04', 'Rule 1/3', 'INSERT thẳng vào SO_CAI (không qua thủ tục) phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T05: SoTien phải > 0
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T05', 'PKT', '2026-03-13', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '1111', '411', 0);
    INSERT INTO ket_qua_test VALUES ('T05', 'Rule 1', 'Dòng chi tiết có SoTien = 0 phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T05', 'Rule 1', 'Dòng chi tiết có SoTien = 0 phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T06: Một dòng không được Nợ và Có cùng một tài khoản
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T06', 'PKT', '2026-03-13', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '1111', '1111', 1000);
    INSERT INTO ket_qua_test VALUES ('T06', 'Rule 1', 'Nợ và Có cùng một tài khoản phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T06', 'Rule 1', 'Nợ và Có cùng một tài khoản phải bị chặn', 'PASS', SQLERRM);
END $$;

-- =====================================================================
-- NHÓM 2: RULE 2 - TÀI KHOẢN HẠCH TOÁN
-- =====================================================================

-- T07: Tài khoản đã ngừng sử dụng (1112)
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T07', 'PKT', '2026-03-13', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '1112', '411', 1000000);
    INSERT INTO ket_qua_test VALUES ('T07', 'Rule 2', 'Hạch toán vào tài khoản ngừng dùng (1112) phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T07', 'Rule 2', 'Hạch toán vào tài khoản ngừng dùng (1112) phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T08: Tài khoản cha (111 có con 1111) không được hạch toán
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T08', 'PKT', '2026-03-13', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '111', '411', 1000000);
    INSERT INTO ket_qua_test VALUES ('T08', 'Rule 2', 'Hạch toán vào tài khoản cha (111) phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T08', 'Rule 2', 'Hạch toán vào tài khoản cha (111) phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T09: Tài khoản không tồn tại
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T09', 'PKT', '2026-03-13', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '9999', '411', 1000000);
    INSERT INTO ket_qua_test VALUES ('T09', 'Rule 2', 'Hạch toán vào tài khoản không tồn tại phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T09', 'Rule 2', 'Hạch toán vào tài khoản không tồn tại phải bị chặn', 'PASS', SQLERRM);
END $$;

-- =====================================================================
-- NHÓM 3: RULE 3 - BẤT BIẾN SAU GHI SỔ
-- (dùng chứng từ PT001/03/26 đã ghi sổ ở bài V01)
-- =====================================================================

-- T10: UPDATE số tiền dòng chi tiết đã ghi sổ
DO $$
BEGIN
    UPDATE CHI_TIET_CHUNG_TU SET SoTien = 1
     WHERE MaCT = (SELECT MaCT FROM CHUNG_TU WHERE MaLoaiCT = 'PT' AND SoCT = 'PT001/03/26') AND SttDong = 1;
    INSERT INTO ket_qua_test VALUES ('T10', 'Rule 3', 'UPDATE số tiền dòng chi tiết đã ghi sổ phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T10', 'Rule 3', 'UPDATE số tiền dòng chi tiết đã ghi sổ phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T11: DELETE dòng chi tiết đã ghi sổ
DO $$
BEGIN
    DELETE FROM CHI_TIET_CHUNG_TU
     WHERE MaCT = (SELECT MaCT FROM CHUNG_TU WHERE MaLoaiCT = 'PT' AND SoCT = 'PT001/03/26') AND SttDong = 1;
    INSERT INTO ket_qua_test VALUES ('T11', 'Rule 3', 'DELETE dòng chi tiết đã ghi sổ phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T11', 'Rule 3', 'DELETE dòng chi tiết đã ghi sổ phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T12: Thêm dòng mới vào chứng từ đã ghi sổ
DO $$
BEGIN
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
    VALUES ((SELECT MaCT FROM CHUNG_TU WHERE MaLoaiCT = 'PT' AND SoCT = 'PT001/03/26'), 99, '1111', '131', 1000);
    INSERT INTO ket_qua_test VALUES ('T12', 'Rule 3', 'Thêm dòng vào chứng từ đã ghi sổ phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T12', 'Rule 3', 'Thêm dòng vào chứng từ đã ghi sổ phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T13: UPDATE header chứng từ đã ghi sổ
DO $$
BEGIN
    UPDATE CHUNG_TU SET LyDo = 'sửa lén' WHERE MaLoaiCT = 'PT' AND SoCT = 'PT001/03/26';
    INSERT INTO ket_qua_test VALUES ('T13', 'Rule 3', 'UPDATE header chứng từ đã ghi sổ phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T13', 'Rule 3', 'UPDATE header chứng từ đã ghi sổ phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T14: DELETE chứng từ đã ghi sổ
DO $$
BEGIN
    DELETE FROM CHUNG_TU WHERE MaLoaiCT = 'PT' AND SoCT = 'PT001/03/26';
    INSERT INTO ket_qua_test VALUES ('T14', 'Rule 3', 'DELETE chứng từ đã ghi sổ phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T14', 'Rule 3', 'DELETE chứng từ đã ghi sổ phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T15: UPDATE / DELETE sổ cái
DO $$
BEGIN
    UPDATE SO_CAI SET SoTienNo = SoTienNo + 1 WHERE MaSoCai = (SELECT MIN(MaSoCai) FROM SO_CAI);
    INSERT INTO ket_qua_test VALUES ('T15a', 'Rule 3', 'UPDATE sổ cái phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T15a', 'Rule 3', 'UPDATE sổ cái phải bị chặn', 'PASS', SQLERRM);
END $$;

DO $$
BEGIN
    DELETE FROM SO_CAI WHERE MaSoCai = (SELECT MIN(MaSoCai) FROM SO_CAI);
    INSERT INTO ket_qua_test VALUES ('T15b', 'Rule 3', 'DELETE sổ cái phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T15b', 'Rule 3', 'DELETE sổ cái phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T16: Gán DaGhiSo = TRUE trực tiếp để lách thủ tục ghi sổ
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T16', 'PKT', '2026-03-13', '2026-M03', NULL);
    UPDATE CHUNG_TU SET DaGhiSo = TRUE WHERE MaCT = v_id;
    INSERT INTO ket_qua_test VALUES ('T16', 'Rule 3', 'UPDATE DaGhiSo = TRUE trực tiếp (không qua thủ tục) phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T16', 'Rule 3', 'UPDATE DaGhiSo = TRUE trực tiếp (không qua thủ tục) phải bị chặn', 'PASS', SQLERRM);
END $$;

-- V03: Sửa sai đúng cách: tạo chứng từ ĐẢO cho PT001/03/26 -> số dư quay về như cũ
DO $$
DECLARE
    v_goc BIGINT; v_dao BIGINT; v_chenh NUMERIC;
BEGIN
    SELECT MaCT INTO v_goc FROM CHUNG_TU WHERE MaLoaiCT = 'PT' AND SoCT = 'PT001/03/26';
    CALL sp_reverse_voucher(v_goc, 'PT002/03/26', '2026-03-15', 'tester');
    SELECT MaCT INTO v_dao FROM CHUNG_TU WHERE MaCTGoc = v_goc;

    -- Cộng dồn (Nợ - Có) của cả 2 chứng từ trên mọi tài khoản phải bằng 0
    SELECT COALESCE(SUM(SoTienNo - SoTienCo), 0) INTO v_chenh FROM SO_CAI WHERE MaCT IN (v_goc, v_dao);
    IF v_dao IS NOT NULL AND v_chenh = 0 AND
       (SELECT SUM(SoTienNo - SoTienCo) FROM SO_CAI WHERE MaCT IN (v_goc, v_dao) AND MaTK = '131') = 0 THEN
        INSERT INTO ket_qua_test VALUES ('V03', 'Rule 3', 'Chứng từ đảo (sp_reverse_voucher) triệt tiêu ảnh hưởng chứng từ gốc', 'PASS',
                                         'Chứng từ gốc ' || v_goc || ' được đảo bởi chứng từ ' || v_dao);
    ELSE
        INSERT INTO ket_qua_test VALUES ('V03', 'Rule 3', 'Chứng từ đảo (sp_reverse_voucher) triệt tiêu ảnh hưởng chứng từ gốc', 'FAIL', 'Số dư không về 0');
    END IF;
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('V03', 'Rule 3', 'Chứng từ đảo (sp_reverse_voucher) triệt tiêu ảnh hưởng chứng từ gốc', 'FAIL', SQLERRM);
END $$;

-- T17: Không đảo 2 lần cùng một chứng từ
DO $$
DECLARE v_goc BIGINT;
BEGIN
    SELECT MaCT INTO v_goc FROM CHUNG_TU WHERE MaLoaiCT = 'PT' AND SoCT = 'PT001/03/26';
    CALL sp_reverse_voucher(v_goc, 'PT003/03/26', '2026-03-16', 'tester');
    INSERT INTO ket_qua_test VALUES ('T17', 'Rule 3', 'Đảo chứng từ lần thứ 2 phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T17', 'Rule 3', 'Đảo chứng từ lần thứ 2 phải bị chặn', 'PASS', SQLERRM);
END $$;

-- =====================================================================
-- NHÓM 4: RULE 4 - KỲ KẾ TOÁN
-- =====================================================================

-- T18: Lập chứng từ vào kỳ đã đóng (2026-M01 đã CLOSED)
DO $$
BEGIN
    PERFORM pg_temp.tao_nhap('TEST-T18', 'PKT', '2026-01-20', '2026-M01', NULL);
    INSERT INTO ket_qua_test VALUES ('T18', 'Rule 4', 'Lập chứng từ vào kỳ CLOSED phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T18', 'Rule 4', 'Lập chứng từ vào kỳ CLOSED phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T19: NgayLap nằm ngoài kỳ đã chọn (kỳ tháng 2 nhưng ngày tháng 3)
DO $$
BEGIN
    PERFORM pg_temp.tao_nhap('TEST-T19', 'PKT', '2026-03-10', '2026-M02', NULL);
    INSERT INTO ket_qua_test VALUES ('T19', 'Rule 4', 'NgayLap nằm ngoài kỳ kế toán đã chọn phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T19', 'Rule 4', 'NgayLap nằm ngoài kỳ kế toán đã chọn phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T20: NgayGhiSo < NgayLap
DO $$
BEGIN
    INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy)
    VALUES ('TEST-T20', '2026-03-20', '2026-03-10', 'PKT', '2026-M03');
    INSERT INTO ket_qua_test VALUES ('T20', 'Rule 4', 'NgayGhiSo < NgayLap phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T20', 'Rule 4', 'NgayGhiSo < NgayLap phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T21: Chứng từ nháp lập khi kỳ còn mở, sau đó kỳ bị đóng -> ghi sổ phải bị chặn
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T21', 'PKT', '2026-03-17', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '1111', '411', 1000000);
    UPDATE KY_KE_TOAN SET TrangThaiKy = 'CLOSED' WHERE MaKy = '2026-M03';
    CALL sp_post_voucher(v_id);
    INSERT INTO ket_qua_test VALUES ('T21', 'Rule 4', 'Ghi sổ vào kỳ vừa bị đóng phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T21', 'Rule 4', 'Ghi sổ vào kỳ vừa bị đóng phải bị chặn', 'PASS', SQLERRM);
END $$;   -- lỗi nên việc đóng kỳ M03 trong khối này cũng được ROLLBACK

-- =====================================================================
-- NHÓM 5: RULE 5 - SoCT DUY NHẤT THEO (LOẠI CT, NIÊN ĐỘ)
-- =====================================================================
DO $$
BEGIN
    PERFORM pg_temp.tao_nhap('PT001/02/26', 'PT', '2026-02-20', '2026-M02', NULL);   -- trùng PT001/02/26 đã có
    INSERT INTO ket_qua_test VALUES ('T22', 'Rule 5', 'Trùng SoCT trong cùng loại chứng từ và năm phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T22', 'Rule 5', 'Trùng SoCT trong cùng loại chứng từ và năm phải bị chặn', 'PASS', SQLERRM);
END $$;

-- =====================================================================
-- NHÓM 6: RULE 6 - CÔNG NỢ PHẢI CÓ ĐỐI TƯỢNG
-- =====================================================================

-- T23: Dòng dùng tài khoản 131 nhưng chứng từ không có MaDoiTuong
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T23', 'HD', '2026-03-13', '2026-M03', NULL);
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '131', '5111', 1000000);
    INSERT INTO ket_qua_test VALUES ('T23', 'Rule 6', 'Tài khoản công nợ 131 nhưng thiếu MaDoiTuong phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T23', 'Rule 6', 'Tài khoản công nợ 131 nhưng thiếu MaDoiTuong phải bị chặn', 'PASS', SQLERRM);
END $$;

-- T24: Lập đúng (có đối tượng), sau đó xóa đối tượng khỏi header rồi ghi sổ -> thủ tục chặn
DO $$
DECLARE v_id BIGINT;
BEGIN
    v_id := pg_temp.tao_nhap('TEST-T24', 'HD', '2026-03-13', '2026-M03', 'KH001');
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien) VALUES (v_id, 1, '131', '5111', 1000000);
    UPDATE CHUNG_TU SET MaDoiTuong = NULL WHERE MaCT = v_id;
    CALL sp_post_voucher(v_id);
    INSERT INTO ket_qua_test VALUES ('T24', 'Rule 6', 'Gỡ MaDoiTuong khỏi chứng từ có công nợ rồi ghi sổ phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T24', 'Rule 6', 'Gỡ MaDoiTuong khỏi chứng từ có công nợ rồi ghi sổ phải bị chặn', 'PASS', SQLERRM);
END $$;

-- =====================================================================
-- NHÓM 7: CHUYÊN BIỆT HÓA DOI_TUONG
-- =====================================================================
DO $$
BEGIN
    INSERT INTO KHACH_HANG (MaDoiTuong, HanMucNo, SoNgayDuocNo) VALUES ('NCC001', 1000, 1);  -- NCC001 là nhà cung cấp
    INSERT INTO ket_qua_test VALUES ('T25', 'EER', 'Thêm nhà cung cấp vào bảng KHACH_HANG phải bị chặn', 'FAIL', 'Không có lỗi');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO ket_qua_test VALUES ('T25', 'EER', 'Thêm nhà cung cấp vào bảng KHACH_HANG phải bị chặn', 'PASS', SQLERRM);
END $$;

-- =====================================================================
-- NHÓM 8: KIỂM TRA NHẤT QUÁN TOÀN HỆ THỐNG
-- =====================================================================
DO $$
DECLARE v_lech INT;
BEGIN
    SELECT COUNT(*) INTO v_lech FROM v_chung_tu_lech;
    IF v_lech = 0 THEN
        INSERT INTO ket_qua_test VALUES ('C01', 'Rule 1', 'Mọi chứng từ đã ghi sổ đều cân Nợ = Có (v_chung_tu_lech rỗng)', 'PASS', '0 chứng từ lệch');
    ELSE
        INSERT INTO ket_qua_test VALUES ('C01', 'Rule 1', 'Mọi chứng từ đã ghi sổ đều cân Nợ = Có (v_chung_tu_lech rỗng)', 'FAIL', v_lech || ' chứng từ lệch');
    END IF;
END $$;

DO $$
DECLARE v_no NUMERIC; v_co NUMERIC;
BEGIN
    SELECT SUM(SoTienNo), SUM(SoTienCo) INTO v_no, v_co FROM SO_CAI;
    IF v_no = v_co THEN
        INSERT INTO ket_qua_test VALUES ('C02', 'Rule 1', 'Tổng Nợ = tổng Có trên toàn bộ sổ cái', 'PASS', 'Nợ = Có = ' || v_no);
    ELSE
        INSERT INTO ket_qua_test VALUES ('C02', 'Rule 1', 'Tổng Nợ = tổng Có trên toàn bộ sổ cái', 'FAIL', 'Nợ = ' || v_no || ', Có = ' || v_co);
    END IF;
END $$;

-- =====================================================================
-- KẾT QUẢ
-- =====================================================================
SELECT ma_test, rule_ap, mo_ta, ket_qua, left(thong_bao, 110) AS thong_bao
  FROM ket_qua_test
 ORDER BY CASE WHEN ma_test LIKE 'V%' THEN 0 WHEN ma_test LIKE 'T%' THEN 1 ELSE 2 END, ma_test;

SELECT ket_qua, COUNT(*) AS so_test FROM ket_qua_test GROUP BY ket_qua;

-- Xem thêm số liệu sổ cái sau khi chạy thử:
-- SELECT * FROM v_bang_can_doi_tai_khoan;
-- SELECT * FROM v_cong_no_doi_tuong;
