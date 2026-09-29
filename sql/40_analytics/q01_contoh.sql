-- ============================================================
-- Q01 — Ukuran keranjang: item per transaksi & nilai per transaksi, hari kerja vs akhir pekan
-- Topik : K3T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)
-- Teknik: agregasi dengan degenerate dimension (transaction_id) + dim_date.akhir_pekan
--
-- Aditivitas: memakai subtotal_rupiah (ADDITIVE), BUKAN total_bayar_trx
-- (SEMI-ADDITIVE, terduplikasi per baris item). Nilai per transaksi dihitung
-- dari SUM(subtotal_rupiah) / COUNT(DISTINCT transaction_id).
--
-- Filter slice k8: outlet A+B+C, 2025, hanya PAID, dan hanya baris berqty positif
-- (retur dikeluarkan supaya ukuran keranjang tidak terdistorsi).
--
-- Kolom keluaran:
--   outlet | jenis_hari | jumlah_transaksi | item_per_transaksi | nilai_per_transaksi
--
-- Jawaban yang diharapkan (1 kalimat):
--   "Rata-rata keranjang sekitar dua item senilai Rp77-79 ribu per transaksi di ketiga outlet,
--    dan selisih hari kerja vs akhir pekan hanya sekitar Rp0-2,5 ribu (tidak ada pola akhir pekan)."
-- ============================================================

SELECT o.outlet_id                                                     AS outlet,
       CASE WHEN d.akhir_pekan THEN 'akhir_pekan' ELSE 'hari_kerja' END AS jenis_hari,
       COUNT(DISTINCT f.transaction_id)                                AS jumlah_transaksi,
       ROUND(COUNT(*)::DOUBLE / COUNT(DISTINCT f.transaction_id), 2)   AS item_per_transaksi,
       ROUND(SUM(f.subtotal_rupiah) / COUNT(DISTINCT f.transaction_id), 0) AS nilai_per_transaksi
FROM fact_transaksi_item f
JOIN dim_date             d ON d.date_sk   = f.date_sk
JOIN dim_outlet           o ON o.outlet_sk = f.outlet_sk
JOIN dim_status_transaksi s ON s.status_sk = f.status_sk
WHERE o.outlet_id IN ('OUT-A', 'OUT-B', 'OUT-C')   -- filter slice k8
  AND d.tahun = 2025                                -- 12 bulan slice k8
  AND s.status_code = 'PAID'
  AND f.qty > 0
GROUP BY o.outlet_id, d.akhir_pekan
ORDER BY o.outlet_id, jenis_hari;
