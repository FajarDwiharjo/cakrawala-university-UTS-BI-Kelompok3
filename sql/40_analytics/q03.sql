-- ============================================================
-- Q03 — Tingkat retur (qty negatif) per outlet per triwulan
-- Topik : K3T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)
-- Teknik: agregasi bersyarat (FILTER) + filter slice
--
-- Latar profiling (python -m pipeline.profile --topic t2 --slice k8):
--   transaction_items.csv punya 628 baris qty negatif dari 31.343 baris (retur).
--
-- Filter slice k8: outlet A+B+C (OUT-D tutup dikecualikan) dan tahun 2025.
-- Kueri ini SENGAJA tidak memfilter status, karena retur adalah baris item
-- berqty negatif apa pun status header-nya.
--
-- Kolom keluaran:
--   outlet | triwulan | baris_item | baris_retur | pct_baris_retur | nilai_retur_rp
--
-- Jawaban yang diharapkan (1 kalimat):
--   "Sekitar 2% baris item (1,75-2,47%) di ketiga outlet adalah retur, dengan nilai retur
--    Rp1,1-1,7 juta per outlet per triwulan; Outlet A triwulan 4 tertinggi (2,47%)."
-- ============================================================

SELECT o.outlet_id                                                    AS outlet,
       d.triwulan,
       COUNT(*)                                                       AS baris_item,
       COUNT(*) FILTER (WHERE f.qty < 0)                              AS baris_retur,
       ROUND(100.0 * COUNT(*) FILTER (WHERE f.qty < 0) / COUNT(*), 2) AS pct_baris_retur,
       -ABS(COALESCE(SUM(f.subtotal_rupiah) FILTER (WHERE f.qty < 0), 0)) AS nilai_retur_rp
FROM fact_transaksi_item f
JOIN dim_date   d ON d.date_sk   = f.date_sk
JOIN dim_outlet o ON o.outlet_sk = f.outlet_sk
WHERE o.outlet_id IN ('OUT-A', 'OUT-B', 'OUT-C')   -- filter slice k8
  AND d.tahun = 2025                                -- 12 bulan slice k8
GROUP BY o.outlet_id, d.triwulan
ORDER BY o.outlet_id, d.triwulan;
