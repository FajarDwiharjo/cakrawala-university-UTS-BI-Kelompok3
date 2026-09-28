-- ============================================================
-- 20_dim_outlet.sql - Dimensi Outlet (Referensi/Geografi)
-- Topik: T2 POS UMKM - Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- SCD Type: Type 1 — data outlet bersifat master referensi.
--   Nama, kota, dan tipe outlet bersifat deskriptif dan relatif stabil.
--   Jika ada koreksi (typo nama atau perubahan tipe), overwrite langsung
--   cukup karena analitik tidak butuh histori perubahan identitas outlet.
--   Status aktif di-overwrite pula (Type 1).
--
-- Catatan slice k8: 3 outlet (A, B, C) - 12 bulan data
-- ============================================================

CREATE OR REPLACE TABLE dim_outlet AS

-- ── Baris dari sumber CSV outlets.csv ─────────────────────────────────────
SELECT
    -- surrogate key: row_number berdasarkan outlet_id
    row_number() OVER (ORDER BY o.outlet_id)    AS outlet_sk,

    o.outlet_id,                                 -- natural key
    o.nama_outlet,
    o.kota,
    o.tipe,                                      -- outlet_pusat | outlet_transit | ...
    -- aktif dinormalkan ke BOOLEAN (konsisten dengan dim_product.is_aktif)
    CASE WHEN lower(trim(o.aktif)) = 'ya' THEN TRUE ELSE FALSE END   AS is_aktif,
    CAST(o.dibuka_sejak AS DATE)                 AS dibuka_sejak

FROM read_csv_auto('data/raw/t2_umkm/outlets.csv', all_varchar=true) AS o

UNION ALL

-- ── Anggota Unknown: transaksi tanpa outlet_id yang dikenali ──────────────
SELECT
    -1                  AS outlet_sk,
    'OUT-UNKNOWN'       AS outlet_id,
    'TIDAK DIKETAHUI'   AS nama_outlet,
    'TIDAK DIKETAHUI'   AS kota,
    'TIDAK DIKETAHUI'   AS tipe,
    FALSE               AS is_aktif,
    DATE '1900-01-01'   AS dibuka_sejak;

-- ============================================================
-- DESAIN CATATAN:
--
-- Mengapa Type 1 (bukan Type 2)?
--   Outlets adalah entitas fisik yang identitasnya stabil. Perubahan nama
--   atau kota outlet sangat jarang dan biasanya merupakan koreksi data,
--   bukan peristiwa bisnis. Histori perubahan identitas outlet tidak relevan
--   untuk analisis penjualan.
--
-- Alternatif yang ditolak:
--   - Type 2: menambah kompleksitas JOIN ke fact table tanpa nilai analitik
--     yang signifikan. Outlet tidak memiliki atribut bisnis yang berubah
--     secara teratur (tidak seperti harga produk).
-- ============================================================
