-- ============================================================
-- Metrik 2: pertumbuhan_mom_omzet (v1, berlaku 2026-09-30)
-- Topik   : T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)
-- Grain   : 1 baris per bulan kalender per outlet
-- Dokumen : docs/kamus_metrik.md (Metrik 2)
-- ============================================================

WITH omzet_bulanan AS (
    SELECT
        o.outlet_id,
        d.tahun,
        d.bulan,
        SUM(f.subtotal_rupiah) AS omzet_bersih
    FROM fact_transaksi_item f
    JOIN dim_date d              ON d.date_sk   = f.date_sk
    JOIN dim_outlet o            ON o.outlet_sk = f.outlet_sk
    JOIN dim_status_transaksi s  ON s.status_sk = f.status_sk
    WHERE s.kategori_final = 'selesai'
      AND o.outlet_id IN ('OUT-A', 'OUT-B', 'OUT-C')
      AND d.tahun = 2025
    GROUP BY o.outlet_id, d.tahun, d.bulan
)
SELECT
    outlet_id,
    tahun,
    bulan,
    omzet_bersih,
    LAG(omzet_bersih) OVER (
        PARTITION BY outlet_id ORDER BY tahun, bulan
    ) AS omzet_bulan_lalu,
    ROUND(
        100.0 * (omzet_bersih - LAG(omzet_bersih) OVER (PARTITION BY outlet_id ORDER BY tahun, bulan))
        / NULLIF(LAG(omzet_bersih) OVER (PARTITION BY outlet_id ORDER BY tahun, bulan), 0),
        1
    ) AS pertumbuhan_mom_pct
FROM omzet_bulanan
ORDER BY outlet_id, tahun, bulan;
