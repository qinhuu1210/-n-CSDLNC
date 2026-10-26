-- =====================================================================
-- FILE 01: TẠO BẢNG (DDL) CHO CSDL KẾ TOÁN TRÊN POSTGRESQL
-- Chuyển từ bản SQL Server của Task 1 sang PostgreSQL.
--
-- CÁCH CHẠY (trong psql hoặc pgAdmin):
--   CREATE DATABASE csdlnc;      -- chạy 1 lần, ở database postgres
--   \c csdlnc                    -- kết nối vào database vừa tạo
--   \i 01_tao_bang.sql
--
-- Khác biệt chính so với SQL Server:
--   NVARCHAR            -> VARCHAR  (PostgreSQL dùng UTF-8 nên gõ tiếng Việt thoải mái)
--   BIT                 -> BOOLEAN  (TRUE / FALSE)
--   DECIMAL(18,2)       -> NUMERIC(18,2)
--   IDENTITY(1,1)       -> GENERATED ALWAYS AS IDENTITY
--   GO                  -> không cần, kết thúc câu lệnh bằng dấu ;
-- =====================================================================

-- Xóa bảng cũ (nếu có) để chạy lại script nhiều lần không bị lỗi.
-- CASCADE: xóa luôn các ràng buộc phụ thuộc.
DROP TABLE IF EXISTS SO_CAI            CASCADE;
DROP TABLE IF EXISTS CHI_TIET_CHUNG_TU CASCADE;
DROP TABLE IF EXISTS CHUNG_TU          CASCADE;
DROP TABLE IF EXISTS NHAN_VIEN         CASCADE;
DROP TABLE IF EXISTS NHA_CUNG_CAP      CASCADE;
DROP TABLE IF EXISTS KHACH_HANG        CASCADE;
DROP TABLE IF EXISTS DOI_TUONG         CASCADE;
DROP TABLE IF EXISTS TAI_KHOAN         CASCADE;
DROP TABLE IF EXISTS LOAI_CHUNG_TU     CASCADE;
DROP TABLE IF EXISTS KY_KE_TOAN        CASCADE;

-- ---------------------------------------------------------------------
-- 1. KỲ KẾ TOÁN
-- ---------------------------------------------------------------------
CREATE TABLE KY_KE_TOAN (
    MaKy         VARCHAR(10) NOT NULL,
    TenKy        VARCHAR(50) NOT NULL,
    NgayBatDau   DATE        NOT NULL,
    NgayKetThuc  DATE        NOT NULL,
    TrangThaiKy  VARCHAR(10) NOT NULL DEFAULT 'OPEN',
    CONSTRAINT PK_KY_KE_TOAN   PRIMARY KEY (MaKy),
    CONSTRAINT CK_TrangThaiKy  CHECK (TrangThaiKy IN ('OPEN', 'CLOSED')),
    CONSTRAINT CK_NgayKy       CHECK (NgayKetThuc >= NgayBatDau)
);

-- ---------------------------------------------------------------------
-- 2. LOẠI CHỨNG TỪ
-- ---------------------------------------------------------------------
CREATE TABLE LOAI_CHUNG_TU (
    MaLoaiCT   VARCHAR(10)  NOT NULL,
    TenLoaiCT  VARCHAR(100) NOT NULL,
    TienTo     VARCHAR(10),
    CONSTRAINT PK_LOAI_CHUNG_TU PRIMARY KEY (MaLoaiCT)
);

-- ---------------------------------------------------------------------
-- 3. TÀI KHOẢN (quan hệ đệ quy: MaTKMe -> MaTK)
-- Cột TheoDoiCongNo là cột BỔ SUNG so với Task 1, dùng cho Rule 6
-- (tài khoản nào bắt buộc phải có Đối tượng công nợ: 131, 331, ...).
-- ---------------------------------------------------------------------
CREATE TABLE TAI_KHOAN (
    MaTK           VARCHAR(20)  NOT NULL,
    TenTK          VARCHAR(100) NOT NULL,
    CapTK          INT          NOT NULL,
    LoaiTK         VARCHAR(20)  NOT NULL,
    TinhChat       VARCHAR(20)  NOT NULL,
    LaTaiKhoanLa   BOOLEAN      NOT NULL DEFAULT TRUE,
    ConSuDung      BOOLEAN      NOT NULL DEFAULT TRUE,
    TheoDoiCongNo  BOOLEAN      NOT NULL DEFAULT FALSE,
    MaTKMe         VARCHAR(20),
    CONSTRAINT PK_TAI_KHOAN PRIMARY KEY (MaTK),
    CONSTRAINT CK_CapTK     CHECK (CapTK > 0),
    CONSTRAINT CK_LoaiTK    CHECK (LoaiTK IN ('TAI_SAN','NO_PHAI_TRA','VON_CHU_SO_HUU','DOANH_THU','CHI_PHI')),
    CONSTRAINT CK_TinhChat  CHECK (TinhChat IN ('DU_NO','DU_CO','LUONG_TINH')),
    CONSTRAINT CK_TK_KhongTuLaMe CHECK (MaTKMe IS NULL OR MaTKMe <> MaTK),
    CONSTRAINT FK_TAIKHOAN_ME FOREIGN KEY (MaTKMe) REFERENCES TAI_KHOAN(MaTK)
);

-- ---------------------------------------------------------------------
-- 4. ĐỐI TƯỢNG (lớp cha) + 3 lớp con (chuyên biệt hóa)
-- ---------------------------------------------------------------------
CREATE TABLE DOI_TUONG (
    MaDoiTuong    VARCHAR(20)  NOT NULL,
    LoaiDoiTuong  VARCHAR(20)  NOT NULL,
    TenDoiTuong   VARCHAR(150) NOT NULL,
    DiaChi        VARCHAR(255),
    MaSoThue      VARCHAR(20),
    DienThoai     VARCHAR(20),
    Email         VARCHAR(100),
    CONSTRAINT PK_DOI_TUONG PRIMARY KEY (MaDoiTuong),
    CONSTRAINT CK_LoaiDoiTuong CHECK (LoaiDoiTuong IN ('KHACH_HANG','NHA_CUNG_CAP','NHAN_VIEN'))
);

CREATE TABLE KHACH_HANG (
    MaDoiTuong    VARCHAR(20)   NOT NULL,
    HanMucNo      NUMERIC(18,2) NOT NULL DEFAULT 0,
    SoNgayDuocNo  INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_KHACH_HANG PRIMARY KEY (MaDoiTuong),
    CONSTRAINT CK_HanMucNo     CHECK (HanMucNo >= 0),
    CONSTRAINT CK_SoNgayDuocNo CHECK (SoNgayDuocNo >= 0),
    CONSTRAINT FK_KHACHHANG_DOITUONG FOREIGN KEY (MaDoiTuong)
        REFERENCES DOI_TUONG(MaDoiTuong) ON DELETE CASCADE
);

CREATE TABLE NHA_CUNG_CAP (
    MaDoiTuong   VARCHAR(20) NOT NULL,
    SoTKNH       VARCHAR(30),
    TenNganHang  VARCHAR(100),
    CONSTRAINT PK_NHA_CUNG_CAP PRIMARY KEY (MaDoiTuong),
    CONSTRAINT FK_NHACUNGCAP_DOITUONG FOREIGN KEY (MaDoiTuong)
        REFERENCES DOI_TUONG(MaDoiTuong) ON DELETE CASCADE
);

CREATE TABLE NHAN_VIEN (
    MaDoiTuong  VARCHAR(20) NOT NULL,
    ChucVu      VARCHAR(50),
    PhongBan    VARCHAR(50),
    CONSTRAINT PK_NHAN_VIEN PRIMARY KEY (MaDoiTuong),
    CONSTRAINT FK_NHANVIEN_DOITUONG FOREIGN KEY (MaDoiTuong)
        REFERENCES DOI_TUONG(MaDoiTuong) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- 5. CHỨNG TỪ (Header)
-- Cột BỔ SUNG so với Task 1:
--   NienDo  : năm của NgayLap, tự tính, phục vụ Rule 5 (SoCT duy nhất
--             trong cùng Loại chứng từ + Niên độ).
--   MaCTGoc : trỏ về chứng từ gốc khi đây là chứng từ hủy/điều chỉnh (Rule 3).
-- Rule 5 thay UNIQUE(SoCT) của bản SQL Server bằng UNIQUE(MaLoaiCT, NienDo, SoCT).
-- ---------------------------------------------------------------------
CREATE TABLE CHUNG_TU (
    MaCT        BIGINT GENERATED ALWAYS AS IDENTITY,
    SoCT        VARCHAR(30)   NOT NULL,
    NgayLap     DATE          NOT NULL,
    NgayGhiSo   DATE          NOT NULL,
    NienDo      INT GENERATED ALWAYS AS (EXTRACT(YEAR FROM NgayLap)::INT) STORED,
    MaLoaiCT    VARCHAR(10)   NOT NULL,
    MaKy        VARCHAR(10)   NOT NULL,
    MaDoiTuong  VARCHAR(20),
    LyDo        VARCHAR(255),
    TongTien    NUMERIC(18,2) NOT NULL DEFAULT 0,
    DaGhiSo     BOOLEAN       NOT NULL DEFAULT FALSE,
    NguoiLap    VARCHAR(50),
    MaCTGoc     BIGINT,
    CONSTRAINT PK_CHUNG_TU PRIMARY KEY (MaCT),
    CONSTRAINT UQ_SoCT_Loai_NienDo UNIQUE (MaLoaiCT, NienDo, SoCT),   -- Rule 5
    CONSTRAINT CK_TongTien  CHECK (TongTien >= 0),
    CONSTRAINT CK_NgayGhiSo CHECK (NgayGhiSo >= NgayLap),             -- Rule 4 (một nửa)
    CONSTRAINT FK_CHUNGTU_LOAICT   FOREIGN KEY (MaLoaiCT)   REFERENCES LOAI_CHUNG_TU(MaLoaiCT),
    CONSTRAINT FK_CHUNGTU_KY       FOREIGN KEY (MaKy)       REFERENCES KY_KE_TOAN(MaKy),
    CONSTRAINT FK_CHUNGTU_DOITUONG FOREIGN KEY (MaDoiTuong) REFERENCES DOI_TUONG(MaDoiTuong),
    CONSTRAINT FK_CHUNGTU_GOC      FOREIGN KEY (MaCTGoc)    REFERENCES CHUNG_TU(MaCT)
);

-- ---------------------------------------------------------------------
-- 6. CHI TIẾT CHỨNG TỪ (thực thể yếu, khóa chính = MaCT + SttDong)
-- CK_No_Khac_Co: một dòng không được hạch toán Nợ và Có cùng 1 tài khoản.
-- ---------------------------------------------------------------------
CREATE TABLE CHI_TIET_CHUNG_TU (
    MaCT      BIGINT        NOT NULL,
    SttDong   INT           NOT NULL,
    MaTKNo    VARCHAR(20)   NOT NULL,
    MaTKCo    VARCHAR(20)   NOT NULL,
    SoTien    NUMERIC(18,2) NOT NULL,
    DienGiai  VARCHAR(255),
    CONSTRAINT PK_CHI_TIET_CHUNG_TU PRIMARY KEY (MaCT, SttDong),
    CONSTRAINT CK_SttDong    CHECK (SttDong > 0),
    CONSTRAINT CK_SoTien     CHECK (SoTien > 0),
    CONSTRAINT CK_No_Khac_Co CHECK (MaTKNo <> MaTKCo),
    CONSTRAINT FK_CHITIET_CHUNGTU FOREIGN KEY (MaCT)
        REFERENCES CHUNG_TU(MaCT) ON DELETE CASCADE,
    CONSTRAINT FK_CHITIET_TKNO FOREIGN KEY (MaTKNo) REFERENCES TAI_KHOAN(MaTK),
    CONSTRAINT FK_CHITIET_TKCO FOREIGN KEY (MaTKCo) REFERENCES TAI_KHOAN(MaTK)
);

-- ---------------------------------------------------------------------
-- 7. SỔ CÁI
-- Mỗi dòng chi tiết khi ghi sổ sinh ra 2 dòng sổ cái:
--   1 dòng bên Nợ (SoTienNo > 0) và 1 dòng bên Có (SoTienCo > 0).
-- ---------------------------------------------------------------------
CREATE TABLE SO_CAI (
    MaSoCai     BIGINT GENERATED ALWAYS AS IDENTITY,
    MaKy        VARCHAR(10)   NOT NULL,
    MaCT        BIGINT        NOT NULL,
    NgayGhiSo   DATE          NOT NULL,
    MaTK        VARCHAR(20)   NOT NULL,
    MaDoiTuong  VARCHAR(20),
    SoTienNo    NUMERIC(18,2) NOT NULL DEFAULT 0,
    SoTienCo    NUMERIC(18,2) NOT NULL DEFAULT 0,
    DienGiai    VARCHAR(255),
    CONSTRAINT PK_SO_CAI PRIMARY KEY (MaSoCai),
    CONSTRAINT CK_SoTienNo    CHECK (SoTienNo >= 0),
    CONSTRAINT CK_SoTienCo    CHECK (SoTienCo >= 0),
    CONSTRAINT CK_SoTienNoCo  CHECK ((SoTienNo > 0 AND SoTienCo = 0) OR (SoTienNo = 0 AND SoTienCo > 0)),
    CONSTRAINT FK_SOCAI_KY       FOREIGN KEY (MaKy)       REFERENCES KY_KE_TOAN(MaKy),
    CONSTRAINT FK_SOCAI_CHUNGTU  FOREIGN KEY (MaCT)       REFERENCES CHUNG_TU(MaCT),
    CONSTRAINT FK_SOCAI_TAIKHOAN FOREIGN KEY (MaTK)       REFERENCES TAI_KHOAN(MaTK),
    CONSTRAINT FK_SOCAI_DOITUONG FOREIGN KEY (MaDoiTuong) REFERENCES DOI_TUONG(MaDoiTuong)
);

-- Index phục vụ tra cứu/báo cáo (khóa ngoại trong PostgreSQL KHÔNG tự tạo index)
CREATE INDEX IX_CHUNGTU_KY       ON CHUNG_TU (MaKy);
CREATE INDEX IX_CHUNGTU_DOITUONG ON CHUNG_TU (MaDoiTuong);
CREATE INDEX IX_SOCAI_CT         ON SO_CAI (MaCT);
CREATE INDEX IX_SOCAI_TK_KY      ON SO_CAI (MaTK, MaKy);
CREATE INDEX IX_TAIKHOAN_ME      ON TAI_KHOAN (MaTKMe);
