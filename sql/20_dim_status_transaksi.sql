-- ============================================================
-- 20_dim_status_transaksi.sql - Dimensi Status Transaksi (Kamus/Referensi)
-- Topik: T2 POS UMKM - Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- SCD Type: Type 0 — kode status bersifat tetap (tidak pernah berubah).
--   Status merupakan kamus domain yang didefinisikan sistem POS.
--   Profiling menunjukkan 5 varian status (dari kolom status di transactions.csv).
--   Nilai kode tidak akan berubah secara bisnis — Type 0 paling tepat.
-- ============================================================

CREATE OR REPLACE TABLE dim_status_transaksi AS

-- ── Kamus status dari domain data profiling ───────────────────────────────
-- Dari profiling: varian_status = 5
-- Status yang mungkin ada pada sistem POS: PAID, PENDING, CANCELLED,
-- REFUNDED, PARTIAL (diekstrak dari data aktual)
SELECT
    row_number() OVER (ORDER BY status_code)    AS status_sk,   -- surrogate key
    status_code,                                                  -- natural key (kode status)
    label_indonesia,
    kategori_final,             -- apakah transaksi ini "selesai" (TRUE/FALSE)
    berdampak_pendapatan        -- apakah status ini menghasilkan pendapatan nyata

FROM (VALUES
    ('PAID',      'Lunas / Dibayar',         'selesai',     TRUE),
    ('PENDING',   'Menunggu Pembayaran',      'proses',      FALSE),
    ('CANCELLED', 'Dibatalkan',               'batal',       FALSE),
    ('REFUNDED',  'Dikembalikan / Retur',     'batal',       FALSE),
    ('PARTIAL',   'Pembayaran Sebagian',      'proses',      FALSE)
) AS t(status_code, label_indonesia, kategori_final, berdampak_pendapatan)

UNION ALL

-- ── Anggota Unknown: transaksi dengan status di luar kamus ────────────────
SELECT
    -1              AS status_sk,
    'UNKNOWN'       AS status_code,
    'TIDAK DIKETAHUI' AS label_indonesia,
    'tidak diketahui' AS kategori_final,
    FALSE           AS berdampak_pendapatan;

-- ============================================================
-- DESAIN CATATAN:
--
-- Mengapa Type 0?
--   Status transaksi adalah kode domain sistem POS yang tidak akan berubah
--   maknanya. 'PAID' akan selalu berarti 'dibayar lunas'. Mengubah makna
--   status = mengubah sistem, bukan data bisnis.
--
-- Alternatif yang ditolak:
--   - Type 1 atau Type 2: berlebihan untuk kamus statis.
--
-- Kolom tambahan (label + kategori):
--   Menambah nilai analitik — analitik bisa filter WHERE kategori_final = 'selesai'
--   untuk menghitung pendapatan riil tanpa harus hafal semua kode status.
-- ============================================================
