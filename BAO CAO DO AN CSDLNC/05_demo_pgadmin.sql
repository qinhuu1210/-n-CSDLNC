-- DEMO TASK 4 - pgAdmin Query Tool
-- Chi dung trong database rieng: ketoan_demo_task4.
-- Chay 01, 02, 03 cua nhom truoc; nen chay 04 mot lan de kiem tra nen.
-- Bat Auto commit, tat Auto rollback on error trong menu Execute.
-- BOI DEN TUNG KHOI roi Execute script; KHONG CHAY CA FILE.
-- BAN TU DONG DANH SO: moi lan chay lai 1A/2A/3A tu tao ma moi.
-- Khong can doi ma, xoa du lieu hay tao lai database.
-- Chay het mot demo truoc khi bat dau demo khac; giu nguyen tab/ket noi
-- trong tung demo de cac khoi sau tim dung chung tu vua tao.
-- Chay khoi 0 mot lan truoc khi dung ban nay (chay lai khoi 0 cung duoc).

-- KHOI 0: kiem tra ket noi va du lieu nen
CREATE SEQUENCE IF NOT EXISTS public.demo4_commit_seq;
CREATE SEQUENCE IF NOT EXISTS public.demo4_rollback_seq;
CREATE SEQUENCE IF NOT EXISTS public.demo4_savepoint_seq;
SELECT version(), current_database(), inet_server_addr(), inet_server_port();
SELECT MaKy, TrangThaiKy FROM KY_KE_TOAN WHERE MaKy = '2026-M03';
-- Can 1 dong OPEN. Ngay demo dung thang 3 theo du lieu mau, khong dung ngay hien tai.

-- KHOI 1A: giao dich thanh cong
BEGIN;
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, LyDo)
VALUES ('D4-C-' || nextval('public.demo4_commit_seq'),
        '2026-03-20', '2026-03-20', 'PKT', '2026-M03', 'Demo COMMIT');
INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
SELECT MaCT, 1, '1111', '411', 100000 FROM CHUNG_TU
WHERE SoCT = 'D4-C-' || currval('public.demo4_commit_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;
CALL sp_post_voucher_by_so('PKT', ('D4-C-' || currval('public.demo4_commit_seq'))::varchar);
COMMIT;

-- KHOI 1B: chup ket qua: TRUE, TongTien = 100000, No = Co = 100000
SELECT c.SoCT, c.DaGhiSo, c.TongTien,
       SUM(s.SoTienNo) AS TongNo, SUM(s.SoTienCo) AS TongCo
FROM CHUNG_TU c JOIN SO_CAI s ON s.MaCT = c.MaCT
WHERE c.SoCT = 'D4-C-' || currval('public.demo4_commit_seq')
  AND c.MaLoaiCT = 'PKT' AND c.NienDo = 2026
GROUP BY c.MaCT, c.SoCT, c.DaGhiSo, c.TongTien;

-- KHOI 2A: them du lieu hop le nhung CHUA commit
BEGIN;
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, LyDo)
VALUES ('D4-R-' || nextval('public.demo4_rollback_seq'),
        '2026-03-20', '2026-03-20', 'PKT', '2026-M03', 'Demo loi giua chung');
INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
SELECT MaCT, 1, '1111', '411', 100000 FROM CHUNG_TU
WHERE SoCT = 'D4-R-' || currval('public.demo4_rollback_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;
SELECT SoCT, TongTien FROM CHUNG_TU
WHERE SoCT = 'D4-R-' || currval('public.demo4_rollback_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;

-- KHOI 2B: CO Y GAY LOI. Chay rieng va chup thong bao CK_SoTien.
INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
SELECT MaCT, 2, '1111', '411', 0 FROM CHUNG_TU
WHERE SoCT = 'D4-R-' || currval('public.demo4_rollback_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;

-- KHOI 2C: sau loi, chay RIENG khoi nay. Ket qua 0 dong.
ROLLBACK;
SELECT * FROM CHUNG_TU
WHERE SoCT = 'D4-R-' || currval('public.demo4_rollback_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;
-- Header va dong chi tiet hop le o 2A deu khong duoc luu.
-- So tu dong co the bi nhay sau ROLLBACK; day la hanh vi binh thuong cua sequence.

-- KHOI 3A: phan dung, dat moc
BEGIN;
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, LyDo)
VALUES ('D4-S-' || nextval('public.demo4_savepoint_seq'),
        '2026-03-20', '2026-03-20', 'PKT', '2026-M03', 'Demo SAVEPOINT');
INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
SELECT MaCT, 1, '1111', '411', 100000 FROM CHUNG_TU
WHERE SoCT = 'D4-S-' || currval('public.demo4_savepoint_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;
SAVEPOINT moc_dung;

-- KHOI 3B: nhap nham them 900000 (van hop le ve rang buoc). Tong tam = 1000000.
INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
SELECT MaCT, 2, '1111', '411', 900000 FROM CHUNG_TU
WHERE SoCT = 'D4-S-' || currval('public.demo4_savepoint_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;
SELECT SoCT, TongTien FROM CHUNG_TU
WHERE SoCT = 'D4-S-' || currval('public.demo4_savepoint_seq')
  AND MaLoaiCT = 'PKT' AND NienDo = 2026;

-- KHOI 3C: huy phan nhap nham, giu dong 1 va ghi so
ROLLBACK TO SAVEPOINT moc_dung;
CALL sp_post_voucher_by_so('PKT', ('D4-S-' || currval('public.demo4_savepoint_seq'))::varchar);
COMMIT;
SELECT c.SoCT, d.SttDong, d.SoTien, c.TongTien, c.DaGhiSo
FROM CHUNG_TU c JOIN CHI_TIET_CHUNG_TU d ON d.MaCT = c.MaCT
WHERE c.SoCT = 'D4-S-' || currval('public.demo4_savepoint_seq')
  AND c.MaLoaiCT = 'PKT' AND c.NienDo = 2026;
-- Chi con dong 1, 100000, TRUE.

-- KHOI 4-SETUP: tao chung tu nhap neu chua co; chay lai cung duoc.
BEGIN;
INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, LyDo)
VALUES ('DEMO4-LOCK', '2026-03-20', '2026-03-20', 'PKT', '2026-M03', 'Ban dau')
ON CONFLICT (MaLoaiCT, NienDo, SoCT) DO NOTHING;
COMMIT;

-- KHOI 4A: chay trong Query Tool A, KHONG commit luc nay
BEGIN;
UPDATE CHUNG_TU SET LyDo = 'Phien A sua'
WHERE SoCT = 'DEMO4-LOCK' AND MaLoaiCT = 'PKT' AND NienDo = 2026;
SELECT pg_backend_pid() AS pid_A;

-- KHOI 4B: chay trong Query Tool B (cung database, ket noi khac)
-- Kiem tra PID B khac PID A truoc khi chay BEGIN/UPDATE.
SELECT pg_backend_pid() AS pid_B;
BEGIN;
SET LOCAL lock_timeout = '120s';
UPDATE CHUNG_TU SET LyDo = 'Phien B sua'
WHERE SoCT = 'DEMO4-LOCK' AND MaLoaiCT = 'PKT' AND NienDo = 2026;
-- B se doi. Chuyen sang A ngay de chay 4C trong vong 120 giay.

-- KHOI 4C: quay lai Query Tool A, chay RIENG
COMMIT;

-- KHOI 4D: quay lai Query Tool B, UPDATE da hoan tat, chay RIENG
COMMIT;
SELECT SoCT, LyDo FROM CHUNG_TU WHERE SoCT = 'DEMO4-LOCK';
-- Ket qua: Phien B sua. Day la demo cho khoa dong, khong phai chan ghi de nghiep vu.
-- Neu timeout: chay ROLLBACK o B, COMMIT o A, roi lam lai 4A -> 4D.

-- KHOI 5: kiem tra nhat quan sau demo
SELECT * FROM v_chung_tu_lech;
-- Mong doi: 0 dong.
-- Demo crash recovery: xem README.md va su_co/06_demo_su_co_pgadmin.sql.
