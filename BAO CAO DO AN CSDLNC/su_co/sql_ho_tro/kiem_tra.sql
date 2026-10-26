DO $$
BEGIN
    IF current_database() <> 'ketoan_demo_crash'
       OR current_setting('cluster_name') <> 'task4_crash_lab' THEN
        RAISE EXCEPTION 'Sai moi truong demo.';
    END IF;
    IF (SELECT COUNT(*) FROM demo4_crash_results) <> 2 THEN
        RAISE EXCEPTION 'Chua co luot demo: chay 6A va 6B truoc.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM demo4_crash_results WHERE loai = 'DA_COMMIT'
        AND so_chung_tu = 1 AND so_chi_tiet = 1 AND so_dong_so_cai = 2
        AND tong_no = 100000 AND tong_co = 100000 AND da_ghi_so
    ) THEN
        RAISE EXCEPTION 'FAIL: chung tu da COMMIT khong dung.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM demo4_crash_results WHERE loai = 'CHUA_COMMIT'
        AND so_chung_tu = 0 AND so_chi_tiet = 0 AND so_dong_so_cai = 0
        AND tong_no = 0 AND tong_co = 0
    ) THEN
        RAISE EXCEPTION 'FAIL: du lieu chua COMMIT van con.';
    END IF;
    IF EXISTS (SELECT 1 FROM v_chung_tu_lech) THEN
        RAISE EXCEPTION 'FAIL: so cai khong can doi.';
    END IF;
END $$;
SELECT 'PASS: da COMMIT con; chua COMMIT khong con; so cai can doi' AS ket_qua;
