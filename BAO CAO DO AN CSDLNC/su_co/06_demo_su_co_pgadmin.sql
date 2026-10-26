-- DEMO CUOI: NGAT MAY CHU GIUA GIAO DICH VA PHUC HOI.
-- Chi chay tren server DEMO_SU_CO, port 55490, database ketoan_demo_crash.
-- Truoc do chay 01_CHUAN_BI_VA_MO.cmd trong thu muc nay.
-- Bat Auto commit, tat Auto rollback on error.
-- BOI DEN TUNG KHOI roi F5. KHONG CHAY CA FILE.
-- Moi luot tu danh so moi, khong can sua ma chung tu.

-- KHOI 6A: luu mot chung tu DA COMMIT de lam doi chung.
DO $$
BEGIN
    IF current_database() <> 'ketoan_demo_crash'
       OR current_setting('cluster_name') <> 'task4_crash_lab'
       OR inet_server_port() <> 55490 THEN
        RAISE EXCEPTION 'Sai server! Hay ket noi DEMO_SU_CO, port 55490, database ketoan_demo_crash.';
    END IF;
END $$;
-- Checkpoint truoc giao dich giup quan sat WAL replay sau su co.
CHECKPOINT;
BEGIN;
SET LOCAL synchronous_commit = on;
DO $$
DECLARE v_run bigint; v_ct bigint;
BEGIN
    INSERT INTO demo4_crash_runs DEFAULT VALUES RETURNING run_id INTO v_run;
    INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, LyDo)
    VALUES ('D4-OK-' || v_run, '2026-03-20', '2026-03-20', 'PKT', '2026-M03',
            'Da COMMIT truoc su co') RETURNING MaCT INTO v_ct;
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
    VALUES (v_ct, 1, '1111', '411', 100000);
    CALL sp_post_voucher(v_ct);
END $$;
COMMIT;
SELECT * FROM demo4_crash_results ORDER BY loai;
-- DA_COMMIT: 1 chung tu, 1 chi tiet, 2 dong so cai, No = Co = 100000.

-- KHOI 6B: tao chung tu thu hai NHUNG KHONG COMMIT.
-- Dung chinh tab vua chay 6A. Giu tab nay mo cho den khi gay su co.
SET application_name = 'demo4_crash_pgadmin';
BEGIN;
DO $$
DECLARE v_run bigint; v_ct bigint;
BEGIN
    IF current_database() <> 'ketoan_demo_crash'
       OR current_setting('cluster_name') <> 'task4_crash_lab'
       OR inet_server_port() <> 55490 THEN
        RAISE EXCEPTION 'Sai server demo su co.';
    END IF;
    SELECT run_id INTO STRICT v_run FROM demo4_crash_current;
    INSERT INTO CHUNG_TU (SoCT, NgayLap, NgayGhiSo, MaLoaiCT, MaKy, LyDo)
    VALUES ('D4-OPEN-' || v_run, '2026-03-20', '2026-03-20', 'PKT', '2026-M03',
            'Chua COMMIT khi may chu bi ngat') RETURNING MaCT INTO v_ct;
    INSERT INTO CHI_TIET_CHUNG_TU (MaCT, SttDong, MaTKNo, MaTKCo, SoTien)
    VALUES (v_ct, 1, '1111', '411', 200000);
    CALL sp_post_voucher(v_ct);
END $$;
SELECT * FROM demo4_crash_results ORDER BY loai;
-- Trong phien nay: ca hai chung tu deu hien thi, nhung D4-OPEN-* CHUA COMMIT.
-- CHUP ANH BANG NAY. Khong bam Commit, Rollback, dong tab hay ngat ket noi.
-- Sang File Explorer, chay 02_GAY_SU_CO.cmd de ngat server demo.
-- Sau do chay 03_KHOI_DONG_LAI.cmd va doi server san sang.
-- Mo Query Tool moi de chay 6C, roi chay 04_LUU_KET_QUA.cmd.

-- KHOI 6C: SAU KHI KHOI DONG LAI, mo Query Tool moi cung server/database.
-- Khong can chay lai 6A/6B. Ma luot demo da duoc luu trong CSDL.
SELECT * FROM demo4_crash_results ORDER BY loai;
-- DA_COMMIT: van con 1 chung tu, 1 chi tiet, 2 so cai, No = Co = 100000.
-- CHUA_COMMIT: 0 chung tu, 0 chi tiet, 0 so cai, No = Co = 0.
SELECT * FROM v_chung_tu_lech;
-- 0 dong: khong co chung tu da ghi so lech No/Co.

-- Chay 04_LUU_KET_QUA.cmd de kiem tra PASS va luu CSV + log phuc hoi.
-- Muon demo lai: bat dau tu 6A -> 6B -> gay su co -> khoi dong -> 6C.
-- Khi xong: chay 05_TAT_SAU_DEMO.cmd de tat rieng may chu nay.
