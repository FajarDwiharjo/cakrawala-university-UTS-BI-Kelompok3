-- ============================================================
-- Q02 — Tren penjualan bersih bulanan per outlet + pertumbuhan MoM
-- Topik : K3T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)
-- Teknik: CTE + window function (LAG, RANK)
-- Grain sumber: fact_transaksi_item (1 baris = 1 item / transaksi / outlet / tanggal)
--
-- Slice k8 (mencerminkan slice kelompok): outlet A+B+C saja (OUT-D sudah tutup,
-- tidak masuk slice) dan 12 bulan kalender 2025. Hanya transaksi berstatus PAID
-- (dim_status_transaksi.status_code) agar retur/void tidak dihitung sebagai omzet.
--
-- Kolom keluaran:
--   outlet | tahun | bulan | omzet_bersih | omzet_bulan_lalu | pertumbuhan_mom_pct | peringkat_bulan
--
-- Jawaban yang diharapkan (1 kalimat):
--   "Omzet bersih PAID ketiga outlet sepanjang 2025 totalnya sekitar Rp1,15 miliar (tiap outlet
--    Rp370-390 juta) dan berfluktuasi tanpa tren naik yang jelas: Februari turun di semua outlet,
--    sedangkan puncaknya berbeda-beda (A Oktober, B Desember, C Juli)."
-- ============================================================

WITH omzet_bulanan AS (
    SELECT o.outlet_id,
           d.tahun,
           d.bulan,
           SUM(f.subtotal_rupiah) AS omzet_bersih      -- qty*harga - diskon; qty negatif (retur) ikut mengurangi
    FROM fact_transaksi_item f
    JOIN dim_date             d ON d.date_sk   = f.date_sk
    JOIN dim_outlet           o ON o.outlet_sk = f.outlet_sk
    JOIN dim_status_transaksi s ON s.status_sk = f.status_sk
    WHERE o.outlet_id IN ('OUT-A', 'OUT-B', 'OUT-C')     -- filter slice k8
      AND d.tahun = 2025                                  -- 12 bulan slice k8
      AND s.status_code = 'PAID'
    GROUP BY o.outlet_id, d.tahun, d.bulan
)
SELECT outlet_id AS outlet,
       tahun,
       bulan,
       omzet_bersih,
       LAG(omzet_bersih) OVER (PARTITION BY outlet_id ORDER BY tahun, bulan) AS omzet_bulan_lalu,
       ROUND(100.0 * (omzet_bersih - LAG(omzet_bersih) OVER (PARTITION BY outlet_id ORDER BY tahun, bulan))
             / NULLIF(LAG(omzet_bersih) OVER (PARTITION BY outlet_id ORDER BY tahun, bulan), 0), 1) AS pertumbuhan_mom_pct,
       RANK() OVER (PARTITION BY outlet_id ORDER BY omzet_bersih DESC)       AS peringkat_bulan
FROM omzet_bulanan
ORDER BY outlet_id, tahun, bulan;
