-- Metrik: omzet_harian_outlet (v1, berlaku 2026-09-30)
-- Grain : tanggal (WIB) x outlet
SELECT
    d.full_date            AS tanggal,
    o.outlet_id,
    SUM(f.subtotal_rupiah) AS omzet_rupiah
FROM fact_transaksi_item f
JOIN dim_date d              ON d.date_sk   = f.date_sk
JOIN dim_outlet o            ON o.outlet_sk = f.outlet_sk
JOIN dim_status_transaksi s  ON s.status_sk = f.status_sk
WHERE s.kategori_final = 'selesai'
GROUP BY 1, 2
ORDER BY 1, 2;