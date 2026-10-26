-- =====================================================================
-- FILE 02: RÀNG BUỘC NGHIỆP VỤ KẾ TOÁN (TRIGGER + THỦ TỤC GHI SỔ)
-- Chạy SAU file 01:   \i 02_rang_buoc_trigger_thu_tuc.sql
--
-- Bảng đối chiếu Rule -> cơ chế cài đặt:
--   Rule 1 (Nợ = Có)            : sp_post_voucher + deferred constraint trigger trên SO_CAI
--   Rule 2 (TK hạch toán)       : trigger trên CHI_TIET_CHUNG_TU (+ kiểm lại lúc ghi sổ)
--   Rule 3 (bất biến sau ghi sổ): trigger trên CHUNG_TU, CHI_TIET_CHUNG_TU, SO_CAI
--                                 + thủ tục sp_reverse_voucher (chứng từ đảo)
--   Rule 4 (kỳ kế toán)         : CHECK (NgayGhiSo >= NgayLap) + trigger trên CHUNG_TU
--   Rule 5 (SoCT duy nhất)      : UNIQUE (MaLoaiCT, NienDo, SoCT) ở file 01
--   Rule 6 (công nợ cần đối tượng): trigger trên CHI_TIET_CHUNG_TU
-- =====================================================================

-- =====================================================================
-- PHẦN A. HÀM DÙNG CHUNG
-- =====================================================================

-- A1. Kiểm tra "cờ ghi sổ": chỉ sp_post_voucher mới bật cờ này.
-- Cờ là một biến cấu hình chỉ sống trong 1 transaction (set_config(..., true)).
-- Mục đích: chặn người dùng UPDATE thẳng DaGhiSo = TRUE hoặc INSERT thẳng vào
-- SO_CAI để lách qua bước kiểm tra cân đối.
CREATE OR REPLACE FUNCTION fn_dang_ghi_so() RETURNS BOOLEAN AS $$
BEGIN
    RETURN COALESCE(current_setting('app.dang_ghi_so', true), 'off') = 'on';
END;
$$ LANGUAGE plpgsql STABLE;

-- A2. Kiểm tra một tài khoản có được phép xuất hiện trong chi tiết chứng từ không (Rule 2).
-- Trả về TRUE nếu tài khoản đó là tài khoản theo dõi công nợ (dùng cho Rule 6).
CREATE OR REPLACE FUNCTION fn_kiem_tra_tk_hach_toan(p_matk VARCHAR) RETURNS BOOLEAN AS $$
DECLARE
    v_tk TAI_KHOAN%ROWTYPE;
BEGIN
    SELECT * INTO v_tk FROM TAI_KHOAN WHERE MaTK = p_matk;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rule 2: tài khoản % không tồn tại', p_matk;
    END IF;

    IF NOT v_tk.ConSuDung THEN
        RAISE EXCEPTION 'Rule 2: tài khoản % đã ngừng sử dụng (ConSuDung = FALSE)', p_matk;
    END IF;

    -- Tài khoản phải là tài khoản lá: cờ LaTaiKhoanLa = TRUE và không có tài khoản con nào.
    IF NOT v_tk.LaTaiKhoanLa
       OR EXISTS (SELECT 1 FROM TAI_KHOAN WHERE MaTKMe = p_matk) THEN
        RAISE EXCEPTION 'Rule 2: tài khoản % không phải tài khoản chi tiết (còn tài khoản con), không được hạch toán', p_matk;
    END IF;

    RETURN v_tk.TheoDoiCongNo;
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================================
-- PHẦN B. TRIGGER CHO TAI_KHOAN (giữ cây tài khoản nhất quán)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_tk_kiem_tra() RETURNS TRIGGER AS $$
DECLARE
    v_me TAI_KHOAN%ROWTYPE;
BEGIN
    IF NEW.MaTKMe IS NOT NULL THEN
        SELECT * INTO v_me FROM TAI_KHOAN WHERE MaTK = NEW.MaTKMe;
        IF FOUND THEN
            -- Tài khoản con phải có cấp lớn hơn tài khoản cha
            IF NEW.CapTK <= v_me.CapTK THEN
                RAISE EXCEPTION 'Tài khoản % (cấp %) phải có cấp lớn hơn tài khoản cha % (cấp %)',
                    NEW.MaTK, NEW.CapTK, v_me.MaTK, v_me.CapTK;
            END IF;
            -- Tự động chuyển tài khoản cha thành "không phải tài khoản lá"
            IF v_me.LaTaiKhoanLa THEN
                UPDATE TAI_KHOAN SET LaTaiKhoanLa = FALSE WHERE MaTK = v_me.MaTK;
            END IF;
        END IF;
    END IF;

    -- Tài khoản đã có con thì không được đánh dấu là tài khoản lá
    IF TG_OP = 'UPDATE' AND NEW.LaTaiKhoanLa
       AND EXISTS (SELECT 1 FROM TAI_KHOAN WHERE MaTKMe = NEW.MaTK) THEN
        RAISE EXCEPTION 'Tài khoản % còn tài khoản con nên không thể là tài khoản lá', NEW.MaTK;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tk_kiem_tra ON TAI_KHOAN;
CREATE TRIGGER trg_tk_kiem_tra
    BEFORE INSERT OR UPDATE ON TAI_KHOAN
    FOR EACH ROW EXECUTE FUNCTION fn_tk_kiem_tra();

-- =====================================================================
-- PHẦN C. TRIGGER CHO 3 BẢNG CON CỦA DOI_TUONG
-- Bảo đảm KHACH_HANG chỉ chứa đối tượng có LoaiDoiTuong = 'KHACH_HANG', v.v.
-- (Chuyên biệt hóa "disjoint": mỗi đối tượng chỉ thuộc đúng 1 loại)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_con_doi_tuong() RETURNS TRIGGER AS $$
DECLARE
    v_loai VARCHAR(20);
BEGIN
    SELECT LoaiDoiTuong INTO v_loai FROM DOI_TUONG WHERE MaDoiTuong = NEW.MaDoiTuong;
    IF v_loai IS DISTINCT FROM TG_ARGV[0] THEN
        RAISE EXCEPTION 'Đối tượng % có LoaiDoiTuong = %, không thể thêm vào bảng %',
            NEW.MaDoiTuong, COALESCE(v_loai, '(không tồn tại)'), TG_TABLE_NAME;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_kh_loai ON KHACH_HANG;
CREATE TRIGGER trg_kh_loai BEFORE INSERT OR UPDATE ON KHACH_HANG
    FOR EACH ROW EXECUTE FUNCTION fn_con_doi_tuong('KHACH_HANG');

DROP TRIGGER IF EXISTS trg_ncc_loai ON NHA_CUNG_CAP;
CREATE TRIGGER trg_ncc_loai BEFORE INSERT OR UPDATE ON NHA_CUNG_CAP
    FOR EACH ROW EXECUTE FUNCTION fn_con_doi_tuong('NHA_CUNG_CAP');

DROP TRIGGER IF EXISTS trg_nv_loai ON NHAN_VIEN;
CREATE TRIGGER trg_nv_loai BEFORE INSERT OR UPDATE ON NHAN_VIEN
    FOR EACH ROW EXECUTE FUNCTION fn_con_doi_tuong('NHAN_VIEN');

-- =====================================================================
-- PHẦN D. TRIGGER CHO CHUNG_TU (Rule 3 + Rule 4)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_ct_kiem_tra() RETURNS TRIGGER AS $$
DECLARE
    v_ky     KY_KE_TOAN%ROWTYPE;
    v_can_kt BOOLEAN;   -- có cần kiểm tra lại kỳ kế toán không
BEGIN
    -- ---- Rule 3: chứng từ đã ghi sổ thì không được sửa ----
    IF TG_OP = 'UPDATE' THEN
        IF OLD.DaGhiSo THEN
            RAISE EXCEPTION 'Rule 3: chứng từ % đã ghi sổ, không được UPDATE. Hãy dùng sp_reverse_voucher để tạo chứng từ hủy/điều chỉnh', OLD.MaCT;
        END IF;
    END IF;

    -- ---- Chỉ cho phép chuyển DaGhiSo FALSE -> TRUE khi do sp_post_voucher thực hiện ----
    IF NEW.DaGhiSo AND NOT fn_dang_ghi_so() THEN
        RAISE EXCEPTION 'Chứng từ chỉ được ghi sổ thông qua CALL sp_post_voucher(MaCT), không được gán DaGhiSo = TRUE trực tiếp';
    END IF;

    -- ---- TongTien là thuộc tính dẫn xuất: do trigger của CHI_TIET_CHUNG_TU tự tính ----
    IF TG_OP = 'INSERT' THEN
        NEW.TongTien := 0;
        v_can_kt := TRUE;
    ELSE
        v_can_kt := (NEW.MaKy      IS DISTINCT FROM OLD.MaKy)
                 OR (NEW.NgayLap   IS DISTINCT FROM OLD.NgayLap)
                 OR (NEW.NgayGhiSo IS DISTINCT FROM OLD.NgayGhiSo)
                 OR (NEW.DaGhiSo   IS DISTINCT FROM OLD.DaGhiSo);
    END IF;

    -- ---- Rule 4: ngày lập và ngày ghi sổ phải nằm trong 1 kỳ đang mở ----
    IF v_can_kt THEN
        SELECT * INTO v_ky FROM KY_KE_TOAN WHERE MaKy = NEW.MaKy;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Rule 4: kỳ kế toán % không tồn tại', NEW.MaKy;
        END IF;
        IF v_ky.TrangThaiKy <> 'OPEN' THEN
            RAISE EXCEPTION 'Rule 4: kỳ kế toán % đang ở trạng thái %, không được lập/ghi sổ chứng từ', v_ky.MaKy, v_ky.TrangThaiKy;
        END IF;
        IF NEW.NgayLap NOT BETWEEN v_ky.NgayBatDau AND v_ky.NgayKetThuc THEN
            RAISE EXCEPTION 'Rule 4: NgayLap % nằm ngoài kỳ % (% đến %)', NEW.NgayLap, v_ky.MaKy, v_ky.NgayBatDau, v_ky.NgayKetThuc;
        END IF;
        IF NEW.NgayGhiSo NOT BETWEEN v_ky.NgayBatDau AND v_ky.NgayKetThuc THEN
            RAISE EXCEPTION 'Rule 4: NgayGhiSo % nằm ngoài kỳ % (% đến %)', NEW.NgayGhiSo, v_ky.MaKy, v_ky.NgayBatDau, v_ky.NgayKetThuc;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ct_kiem_tra ON CHUNG_TU;
CREATE TRIGGER trg_ct_kiem_tra
    BEFORE INSERT OR UPDATE ON CHUNG_TU
    FOR EACH ROW EXECUTE FUNCTION fn_ct_kiem_tra();

-- Rule 3: không cho DELETE chứng từ đã ghi sổ
CREATE OR REPLACE FUNCTION fn_ct_chan_xoa() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.DaGhiSo THEN
        RAISE EXCEPTION 'Rule 3: chứng từ % đã ghi sổ, không được DELETE. Hãy dùng sp_reverse_voucher để hủy/điều chỉnh', OLD.MaCT;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ct_chan_xoa ON CHUNG_TU;
CREATE TRIGGER trg_ct_chan_xoa
    BEFORE DELETE ON CHUNG_TU
    FOR EACH ROW EXECUTE FUNCTION fn_ct_chan_xoa();

-- =====================================================================
-- PHẦN E. TRIGGER CHO CHI_TIET_CHUNG_TU (Rule 2, 3, 6)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_ctct_kiem_tra() RETURNS TRIGGER AS $$
DECLARE
    v_ct CHUNG_TU%ROWTYPE;
    v_no BOOLEAN;
    v_co BOOLEAN;
BEGIN
    -- ---- Rule 3: dòng cũ thuộc chứng từ đã ghi sổ thì không được sửa/xóa ----
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        SELECT * INTO v_ct FROM CHUNG_TU WHERE MaCT = OLD.MaCT;
        -- Nếu không tìm thấy (chứng từ đang bị xóa dây chuyền) thì cho qua
        IF FOUND AND v_ct.DaGhiSo THEN
            RAISE EXCEPTION 'Rule 3: chứng từ % đã ghi sổ, không được % dòng chi tiết', OLD.MaCT, TG_OP;
        END IF;
    END IF;

    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        SELECT * INTO v_ct FROM CHUNG_TU WHERE MaCT = NEW.MaCT;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Chứng từ % không tồn tại', NEW.MaCT;
        END IF;
        IF v_ct.DaGhiSo THEN
            RAISE EXCEPTION 'Rule 3: chứng từ % đã ghi sổ, không được thêm/sửa dòng chi tiết', NEW.MaCT;
        END IF;

        -- ---- Rule 2: tài khoản Nợ và Có phải active và là tài khoản lá ----
        v_no := fn_kiem_tra_tk_hach_toan(NEW.MaTKNo);
        v_co := fn_kiem_tra_tk_hach_toan(NEW.MaTKCo);

        -- ---- Rule 6: có tài khoản công nợ thì chứng từ phải có đối tượng ----
        IF (v_no OR v_co) AND v_ct.MaDoiTuong IS NULL THEN
            RAISE EXCEPTION 'Rule 6: dòng % của chứng từ % dùng tài khoản công nợ (% / %) nên chứng từ phải có MaDoiTuong',
                NEW.SttDong, NEW.MaCT, NEW.MaTKNo, NEW.MaTKCo;
        END IF;

        RETURN NEW;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ctct_kiem_tra ON CHI_TIET_CHUNG_TU;
CREATE TRIGGER trg_ctct_kiem_tra
    BEFORE INSERT OR UPDATE OR DELETE ON CHI_TIET_CHUNG_TU
    FOR EACH ROW EXECUTE FUNCTION fn_ctct_kiem_tra();

-- Tự động tính lại CHUNG_TU.TongTien (thuộc tính dẫn xuất) mỗi khi dòng chi tiết thay đổi
CREATE OR REPLACE FUNCTION fn_ctct_cap_nhat_tong() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        UPDATE CHUNG_TU
           SET TongTien = COALESCE((SELECT SUM(SoTien) FROM CHI_TIET_CHUNG_TU WHERE MaCT = NEW.MaCT), 0)
         WHERE MaCT = NEW.MaCT;
    END IF;
    IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND OLD.MaCT <> NEW.MaCT) THEN
        UPDATE CHUNG_TU
           SET TongTien = COALESCE((SELECT SUM(SoTien) FROM CHI_TIET_CHUNG_TU WHERE MaCT = OLD.MaCT), 0)
         WHERE MaCT = OLD.MaCT;
    END IF;
    RETURN NULL;   -- trigger AFTER nên giá trị trả về bị bỏ qua
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ctct_cap_nhat_tong ON CHI_TIET_CHUNG_TU;
CREATE TRIGGER trg_ctct_cap_nhat_tong
    AFTER INSERT OR UPDATE OR DELETE ON CHI_TIET_CHUNG_TU
    FOR EACH ROW EXECUTE FUNCTION fn_ctct_cap_nhat_tong();

-- =====================================================================
-- PHẦN F. TRIGGER CHO SO_CAI
-- =====================================================================

-- F1. Sổ cái chỉ được ghi thêm (append-only): cấm UPDATE/DELETE (Rule 3)
--     và chỉ sp_post_voucher mới được INSERT.
CREATE OR REPLACE FUNCTION fn_socai_bao_ve() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        RAISE EXCEPTION 'Rule 3: sổ cái không được % trực tiếp. Hãy dùng sp_reverse_voucher', TG_OP;
    END IF;
    IF NOT fn_dang_ghi_so() THEN
        RAISE EXCEPTION 'Sổ cái chỉ được ghi thông qua CALL sp_post_voucher(MaCT)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_socai_bao_ve ON SO_CAI;
CREATE TRIGGER trg_socai_bao_ve
    BEFORE INSERT OR UPDATE OR DELETE ON SO_CAI
    FOR EACH ROW EXECUTE FUNCTION fn_socai_bao_ve();

-- F2. DEFERRED CONSTRAINT TRIGGER - Rule 1 (tổng Nợ = tổng Có trên mỗi chứng từ)
-- "DEFERRABLE INITIALLY DEFERRED" nghĩa là trigger KHÔNG chạy ngay sau từng dòng INSERT,
-- mà chạy MỘT LẦN ở thời điểm COMMIT, khi mọi dòng của chứng từ đã được ghi xong.
-- Nhờ vậy ta insert từng dòng lẻ (lúc đó tạm thời chưa cân) vẫn được, nhưng nếu đến
-- COMMIT mà tổng Nợ <> tổng Có thì cả transaction bị ROLLBACK.
CREATE OR REPLACE FUNCTION fn_socai_can_doi() RETURNS TRIGGER AS $$
DECLARE
    v_mact   BIGINT;
    v_no     NUMERIC(18,2);
    v_co     NUMERIC(18,2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_mact := OLD.MaCT;
    ELSE
        v_mact := NEW.MaCT;
    END IF;

    SELECT COALESCE(SUM(SoTienNo), 0), COALESCE(SUM(SoTienCo), 0)
      INTO v_no, v_co
      FROM SO_CAI WHERE MaCT = v_mact;

    IF v_no <> v_co THEN
        RAISE EXCEPTION 'Rule 1: chứng từ % không cân đối Nợ - Có! (Nợ = %, Có = %)', v_mact, v_no, v_co;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_socai_can_doi ON SO_CAI;
CREATE CONSTRAINT TRIGGER trg_socai_can_doi
    AFTER INSERT OR UPDATE OR DELETE ON SO_CAI
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_socai_can_doi();

-- =====================================================================
-- PHẦN G. THỦ TỤC GHI SỔ: sp_post_voucher(p_MaCT)
-- Toàn bộ thủ tục chạy trong 1 transaction của người gọi. Bất kỳ RAISE EXCEPTION
-- nào cũng làm cả transaction bị ROLLBACK -> không bao giờ có chứng từ ghi sổ dở dang.
--
-- Cách dùng:
--   BEGIN;
--   CALL sp_post_voucher(1);
--   COMMIT;
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_post_voucher(p_mact BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ct       CHUNG_TU%ROWTYPE;
    v_so_dong  INT;
    v_tong_ct  NUMERIC(18,2);
    v_tong_no  NUMERIC(18,2);
    v_tong_co  NUMERIC(18,2);
    r          RECORD;
    v_cong_no  BOOLEAN;
BEGIN
    -- 1. Khóa dòng chứng từ để không ai sửa trong lúc đang ghi sổ
    SELECT * INTO v_ct FROM CHUNG_TU WHERE MaCT = p_mact FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Chứng từ % không tồn tại', p_mact;
    END IF;
    IF v_ct.DaGhiSo THEN
        RAISE EXCEPTION 'Chứng từ % đã được ghi sổ trước đó', p_mact;
    END IF;

    -- 2. Chứng từ phải có ít nhất 1 dòng và tổng tiền > 0 (Rule 1: tổng > 0)
    SELECT COUNT(*), COALESCE(SUM(SoTien), 0)
      INTO v_so_dong, v_tong_ct
      FROM CHI_TIET_CHUNG_TU WHERE MaCT = p_mact;
    IF v_so_dong = 0 OR v_tong_ct <= 0 THEN
        RAISE EXCEPTION 'Chứng từ % không có dòng chi tiết hợp lệ (tổng tiền phải > 0)', p_mact;
    END IF;

    -- 3. Tổng tiền ở header phải khớp tổng các dòng chi tiết
    IF v_ct.TongTien <> v_tong_ct THEN
        RAISE EXCEPTION 'Chứng từ %: TongTien ở header (%) khác tổng chi tiết (%)', p_mact, v_ct.TongTien, v_tong_ct;
    END IF;

    -- 4. Kiểm tra lại Rule 2 và Rule 6 (tài khoản có thể đã bị ngừng dùng sau khi lập nháp)
    FOR r IN SELECT MaTKNo, MaTKCo FROM CHI_TIET_CHUNG_TU WHERE MaCT = p_mact LOOP
        v_cong_no := fn_kiem_tra_tk_hach_toan(r.MaTKNo);
        IF fn_kiem_tra_tk_hach_toan(r.MaTKCo) THEN
            v_cong_no := TRUE;
        END IF;
        IF v_cong_no AND v_ct.MaDoiTuong IS NULL THEN
            RAISE EXCEPTION 'Rule 6: chứng từ % có tài khoản công nợ nhưng chưa có MaDoiTuong', p_mact;
        END IF;
    END LOOP;

    -- 5. Bật cờ ghi sổ (chỉ có hiệu lực trong transaction này)
    PERFORM set_config('app.dang_ghi_so', 'on', true);

    -- 6. Sinh sổ cái: mỗi dòng chi tiết -> 1 dòng bên Nợ + 1 dòng bên Có.
    --    MaDoiTuong chỉ ghi vào sổ cái với tài khoản công nợ (theo dõi chi tiết theo đối tượng).
    INSERT INTO SO_CAI (MaKy, MaCT, NgayGhiSo, MaTK, MaDoiTuong, SoTienNo, SoTienCo, DienGiai)
    SELECT v_ct.MaKy, c.MaCT, v_ct.NgayGhiSo, c.MaTKNo,
           CASE WHEN tk.TheoDoiCongNo THEN v_ct.MaDoiTuong END,
           c.SoTien, 0, c.DienGiai
      FROM CHI_TIET_CHUNG_TU c JOIN TAI_KHOAN tk ON tk.MaTK = c.MaTKNo
     WHERE c.MaCT = p_mact
    UNION ALL
    SELECT v_ct.MaKy, c.MaCT, v_ct.NgayGhiSo, c.MaTKCo,
           CASE WHEN tk.TheoDoiCongNo THEN v_ct.MaDoiTuong END,
           0, c.SoTien, c.DienGiai
      FROM CHI_TIET_CHUNG_TU c JOIN TAI_KHOAN tk ON tk.MaTK = c.MaTKCo
     WHERE c.MaCT = p_mact;

    -- 7. Kiểm tra cân đối Nợ - Có trên sổ cái vừa sinh (Rule 1)
    SELECT COALESCE(SUM(SoTienNo), 0), COALESCE(SUM(SoTienCo), 0)
      INTO v_tong_no, v_tong_co
      FROM SO_CAI WHERE MaCT = p_mact;

    IF v_tong_no <> v_tong_co OR v_tong_no <> v_tong_ct THEN
        RAISE EXCEPTION 'Chứng từ % không cân đối Nợ - Có!', p_mact;
    END IF;

    -- 8. Đánh dấu đã ghi sổ (trigger sẽ kiểm tra kỳ kế toán còn OPEN - Rule 4)
    UPDATE CHUNG_TU SET DaGhiSo = TRUE WHERE MaCT = p_mact;

    -- 9. Tắt cờ
    PERFORM set_config('app.dang_ghi_so', 'off', true);

    RAISE NOTICE 'Đã ghi sổ chứng từ % (% dòng, tổng tiền %)', p_mact, v_so_dong, v_tong_ct;
END;
$$;

-- G2. Tiện ích: ghi sổ theo (Loại chứng từ, Số chứng từ) thay vì theo MaCT.
-- PostgreSQL không cho dùng truy vấn con trong CALL, nên cần thủ tục bọc này để
-- script dữ liệu mẫu gọi được:  CALL sp_post_voucher_by_so('PT', 'PT001/02/26');
CREATE OR REPLACE PROCEDURE sp_post_voucher_by_so(p_maloaict VARCHAR, p_soct VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mact BIGINT;
BEGIN
    SELECT MaCT INTO v_mact FROM CHUNG_TU WHERE MaLoaiCT = p_maloaict AND SoCT = p_soct;
    IF v_mact IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy chứng từ loại % số %', p_maloaict, p_soct;
    END IF;
    CALL sp_post_voucher(v_mact);
END;
$$;

-- =====================================================================
-- PHẦN H. THỦ TỤC HỦY/ĐIỀU CHỈNH: sp_reverse_voucher
-- Rule 3 cấm sửa chứng từ đã ghi sổ, nên muốn sửa sai phải lập chứng từ ĐẢO:
-- sao chép các dòng của chứng từ gốc nhưng đổi chỗ Nợ <-> Có, rồi ghi sổ luôn.
-- Kết quả: số dư các tài khoản quay về như chưa có chứng từ gốc,
-- nhưng cả 2 chứng từ vẫn nằm trong sổ để kiểm toán.
--
--   CALL sp_reverse_voucher(p_mact, 'SoCT mới', 'ngày đảo', 'người lập');
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_reverse_voucher(
    p_mact       BIGINT,
    p_so_ct_moi  VARCHAR,
    p_ngay       DATE,
    p_nguoi_lap  VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_goc  CHUNG_TU%ROWTYPE;
    v_ky   VARCHAR(10);
    v_moi  BIGINT;
BEGIN
    SELECT * INTO v_goc FROM CHUNG_TU WHERE MaCT = p_mact;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Chứng từ % không tồn tại', p_mact;
    END IF;
    IF NOT v_goc.DaGhiSo THEN
        RAISE EXCEPTION 'Chứng từ % chưa ghi sổ: chứng từ nháp cứ sửa hoặc xóa trực tiếp, không cần đảo', p_mact;
    END IF;
    IF EXISTS (SELECT 1 FROM CHUNG_TU WHERE MaCTGoc = p_mact) THEN
        RAISE EXCEPTION 'Chứng từ % đã có chứng từ đảo, không đảo lần 2', p_mact;
    END IF;

    -- Tìm kỳ đang mở chứa ngày đảo
    SELECT MaKy INTO v_ky FROM KY_KE_TOAN
     WHERE TrangThaiKy = 'OPEN' AND p_ngay BETWEEN NgayBatDau AND NgayKetThuc;
    IF v_ky IS NULL THEN
        RAISE EXCEPTION 'Rule 4: không có kỳ kế toán nào đang mở chứa ngày %', p_ngay;
    END IF;

    INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, MaDoiTuong, LyDo, NguoiLap, MaCTGoc)
    VALUES (p_so_ct_moi, p_ngay, p_ngay, v_goc.MaLoaiCT, v_ky, v_goc.MaDoiTuong,
            'Hủy/điều chỉnh chứng từ ' || v_goc.SoCT,
            COALESCE(p_nguoi_lap, v_goc.NguoiLap), p_mact)
    RETURNING MaCT INTO v_moi;

    -- Đổi chỗ tài khoản Nợ <-> Có
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien, DienGiai)
    SELECT v_moi, SttDong, MaTKCo, MaTKNo, SoTien, 'Đảo: ' || COALESCE(DienGiai, '')
      FROM CHI_TIET_CHUNG_TU WHERE MaCT = p_mact;

    CALL sp_post_voucher(v_moi);

    RAISE NOTICE 'Đã đảo chứng từ % bằng chứng từ mới % (%)', p_mact, v_moi, p_so_ct_moi;
END;
$$;

-- =====================================================================
-- PHẦN I. VIEW BÁO CÁO (dùng để kiểm tra kết quả ghi sổ)
-- =====================================================================

-- Bảng cân đối tài khoản: phát sinh Nợ, phát sinh Có theo từng kỳ và tài khoản
CREATE OR REPLACE VIEW v_bang_can_doi_tai_khoan AS
SELECT s.MaKy, s.MaTK, tk.TenTK,
       SUM(s.SoTienNo) AS PhatSinhNo,
       SUM(s.SoTienCo) AS PhatSinhCo
  FROM SO_CAI s JOIN TAI_KHOAN tk ON tk.MaTK = s.MaTK
 GROUP BY s.MaKy, s.MaTK, tk.TenTK
 ORDER BY s.MaKy, s.MaTK;

-- Công nợ theo đối tượng: dư Nợ (phải thu) - dư Có (phải trả) trên các tài khoản công nợ
CREATE OR REPLACE VIEW v_cong_no_doi_tuong AS
SELECT s.MaTK, s.MaDoiTuong, dt.TenDoiTuong,
       SUM(s.SoTienNo) AS PhatSinhNo,
       SUM(s.SoTienCo) AS PhatSinhCo,
       SUM(s.SoTienNo) - SUM(s.SoTienCo) AS ChenhLech
  FROM SO_CAI s JOIN DOI_TUONG dt ON dt.MaDoiTuong = s.MaDoiTuong
 WHERE s.MaDoiTuong IS NOT NULL
 GROUP BY s.MaTK, s.MaDoiTuong, dt.TenDoiTuong
 ORDER BY s.MaTK, s.MaDoiTuong;

-- Kiểm tra nhanh tính nhất quán toàn hệ thống: mọi chứng từ đã ghi sổ phải cân Nợ = Có.
-- Nếu view này trả về 0 dòng nghĩa là CSDL đang nhất quán.
CREATE OR REPLACE VIEW v_chung_tu_lech AS
SELECT ct.MaCT, ct.SoCT,
       COALESCE(SUM(s.SoTienNo), 0) AS TongNo,
       COALESCE(SUM(s.SoTienCo), 0) AS TongCo
  FROM CHUNG_TU ct LEFT JOIN SO_CAI s ON s.MaCT = ct.MaCT
 WHERE ct.DaGhiSo
 GROUP BY ct.MaCT, ct.SoCT
HAVING COALESCE(SUM(s.SoTienNo), 0) <> COALESCE(SUM(s.SoTienCo), 0)
    OR COALESCE(SUM(s.SoTienNo), 0) = 0;
