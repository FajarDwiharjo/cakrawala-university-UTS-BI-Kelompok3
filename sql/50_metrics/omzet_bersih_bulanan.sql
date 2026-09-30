-- ============================================================
-- D6 / UTS item 5 — Metrik: Omzet Bersih Bulanan per Outlet
-- Topik : K3T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- Definisi (kamus_metrik.md, baris 2):
--   Total nilai penjualan item (qty × harga − diskon) dari transaksi
--   berstatus PAID dalam satu bulan kalender di satu outlet,
--   setelah nilai retur (qty negatif) sudah mengurangi total.
--
-- Grain: satu outlet × satu bulan kalender
-- Satuan: Rupiah (IDR), bilangan bulat
-- Filter default: status PAID, outlet A+B+C, tahun 2025
--
-- Measure yang dipakai: subtotal_rupiah (ADDITIVE)
--   = qty * harga_satuan - diskon
--   Retur (qty negatif) otomatis mengurangi total karena subtotal_rupiah
--   sudah menghitung qty negatif sebagai nilai negatif.
--   JANGAN gunakan total_bayar_trx (SEMI-ADDITIVE) karena akan
--   menghitung ulang nilai header transaksi untuk setiap baris item.
-- ============================================================

SELECT
    o.outlet_id                                            AS outlet,
    d.tahun,
    d.bulan,
    CAST(SUM(f.subtotal_rupiah) AS BIGINT)                 AS omzet_bersih_rp,

    -- kolom bantu untuk validasi / audit
    COUNT(DISTINCT f.transaction_id)                       AS jumlah_transaksi,
    COUNT(*)                                               AS jumlah_baris_item,
    COUNT(*) FILTER (WHERE f.qty < 0)                      AS jumlah_baris_retur

FROM fact_transaksi_item      f
JOIN dim_date                 d ON d.date_sk   = f.date_sk
JOIN dim_outlet               o ON o.outlet_sk = f.outlet_sk
JOIN dim_status_transaksi     s ON s.status_sk = f.status_sk

-- Filter default (kamus_metrik.md, baris 10)
WHERE s.status_code = 'PAID'
  AND o.outlet_id IN ('OUT-A', 'OUT-B', 'OUT-C')   -- slice k8
  AND d.tahun = 2025                                -- 12 bulan

GROUP BY o.outlet_id, d.tahun, d.bulan
ORDER BY o.outlet_id, d.tahun, d.bulan;

-- ============================================================
-- Guard test (kamus_metrik.md — "Cara di-gaming & guard test"):
-- Jalankan query di bawah ini setelah load; hasilnya harus 0.
-- Jika > 0 artinya ada item_id duplikat per transaksi di fact
-- yang berpotensi menyebabkan double-counting omzet.
-- ============================================================
-- SELECT count(*)
-- FROM (
--     SELECT f.transaction_id
--     FROM fact_transaksi_item f
--     JOIN dim_status_transaksi s ON s.status_sk = f.status_sk
--     WHERE s.status_code = 'PAID'
--     GROUP BY f.transaction_id
--     HAVING count(DISTINCT f.item_id) <> count(f.item_id)
-- );
