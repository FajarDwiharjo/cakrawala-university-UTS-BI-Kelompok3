-- ============================================================
-- Metrik 3: rasio_retur_triwulan (v1, berlaku 2026-09-30)
-- Topik   : T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)
-- Grain   : 1 baris per triwulan kalender per outlet
-- Dokumen : docs/kamus_metrik.md (Metrik 3)
-- ============================================================

SELECT
    o.outlet_id,
    d.triwulan,
    COUNT(*) AS total_baris_item,
    COUNT(*) FILTER (WHERE f.qty < 0) AS baris_retur,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE f.qty < 0) / COUNT(*),
        2
    ) AS rasio_retur_pct,
    -ABS(COALESCE(SUM(f.subtotal_rupiah) FILTER (WHERE f.qty < 0), 0)) AS nilai_retur_rupiah
FROM fact_transaksi_item f
JOIN dim_date d   ON d.date_sk   = f.date_sk
JOIN dim_outlet o ON o.outlet_sk = f.outlet_sk
WHERE o.outlet_id IN ('OUT-A', 'OUT-B', 'OUT-C')
  AND d.tahun = 2025
GROUP BY o.outlet_id, d.triwulan
ORDER BY o.outlet_id, d.triwulan;
