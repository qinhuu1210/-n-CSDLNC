CREATE TABLE IF NOT EXISTS demo4_crash_runs (
    run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE VIEW demo4_crash_current AS
SELECT run_id, created_at FROM demo4_crash_runs ORDER BY run_id DESC LIMIT 1;

CREATE OR REPLACE VIEW demo4_crash_results AS
WITH targets AS (
    SELECT run_id, 'DA_COMMIT'::text AS loai, 'D4-OK-' || run_id AS soct
    FROM demo4_crash_current
    UNION ALL
    SELECT run_id, 'CHUA_COMMIT', 'D4-OPEN-' || run_id
    FROM demo4_crash_current
)
SELECT t.run_id AS lan_demo, t.loai, t.soct,
       CASE WHEN c.MaCT IS NULL THEN 0 ELSE 1 END AS so_chung_tu,
       d.so_chi_tiet, s.so_dong_so_cai, s.tong_no, s.tong_co,
       c.DaGhiSo AS da_ghi_so
FROM targets t
LEFT JOIN CHUNG_TU c ON c.SoCT = t.soct AND c.MaLoaiCT = 'PKT' AND c.NienDo = 2026
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS so_chi_tiet FROM CHI_TIET_CHUNG_TU WHERE MaCT = c.MaCT
) d ON true
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS so_dong_so_cai,
           COALESCE(SUM(SoTienNo), 0) AS tong_no,
           COALESCE(SUM(SoTienCo), 0) AS tong_co
    FROM SO_CAI WHERE MaCT = c.MaCT
) s ON true;
