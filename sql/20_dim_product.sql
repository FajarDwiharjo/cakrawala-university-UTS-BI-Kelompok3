-- ============================================================
-- 20_dim_product.sql - Dimensi Produk (Entitas Utama)
-- Topik: T2 POS UMKM - Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- SCD Type: Type 2 — harga_satuan dan status aktif DAPAT BERUBAH
--   (produk bisa nonaktif atau berubah harga; histori harga penting
--    untuk rekonsiliasi nilai transaksi historis)
--
-- Kolom wajib:
--   * product_sk   : surrogate key (row_number, bukan ID sumber)
--   * product_id   : natural key / kunci bisnis dari sumber CSV
--   * valid_from, valid_to, is_current : Type 2 histori
-- ============================================================

CREATE OR REPLACE TABLE dim_product AS

-- ── Snapshot aktif (satu baris per produk per periode harga) ──────────────
SELECT
    -- surrogate key: urutan berdasarkan produk dan tanggal berlaku
    row_number() OVER (
        ORDER BY p.product_id, p.harga_berlaku_dari
    )                                   AS product_sk,

    p.product_id,                        -- natural key (disimpan, bukan PK)
    p.nama_produk,
    p.kategori,
    CAST(p.harga_satuan AS DECIMAL(15,2))   AS harga_satuan,

    -- SCD Type 2: valid_from = tanggal harga mulai berlaku
    -- COALESCE guard: jika harga_berlaku_dari NULL (data kotor), fallback ke awal periode data
    COALESCE(CAST(p.harga_berlaku_dari AS DATE), DATE '2024-01-01')   AS valid_from,

    -- valid_to = 1 hari sebelum versi berikutnya (atau far-future untuk baris aktif)
    COALESCE(
        CAST(
            lead(p.harga_berlaku_dari) OVER (
                PARTITION BY p.product_id
                ORDER BY p.harga_berlaku_dari
            ) - INTERVAL 1 DAY
            AS DATE
        ),
        DATE '9999-12-31'
    )                                   AS valid_to,

    -- is_current: hanya TRUE pada baris dengan valid_to = 9999-12-31
    CASE
        WHEN lead(p.harga_berlaku_dari) OVER (
            PARTITION BY p.product_id
            ORDER BY p.harga_berlaku_dari
        ) IS NULL THEN TRUE
        ELSE FALSE
    END                                 AS is_current,

    -- status aktif dari sumber (ya/tidak) → dinormalkan ke BOOLEAN
    CASE WHEN lower(trim(p.aktif)) = 'ya' THEN TRUE ELSE FALSE END   AS is_aktif

FROM read_csv_auto('data/raw/t2_umkm/products.csv', all_varchar=true) AS p

UNION ALL

-- ── Anggota Unknown: transaksi tanpa product_id yang valid ─────────────────
-- Profiling: 1 FK orphan di transaction_items → product_id tidak ada di products.csv
SELECT
    -1                              AS product_sk,
    'PRD-UNKNOWN'                   AS product_id,
    'TIDAK DIKETAHUI'               AS nama_produk,
    'TIDAK DIKETAHUI'               AS kategori,
    CAST(0 AS DECIMAL(15,2))        AS harga_satuan,
    DATE '1900-01-01'               AS valid_from,
    DATE '9999-12-31'               AS valid_to,
    TRUE                            AS is_current,
    FALSE                           AS is_aktif;

-- ============================================================
-- GRAIN & DESAIN CATATAN:
--
-- Mengapa Type 2?
--   Dari profiling: products.csv memiliki kolom harga_berlaku_dari yang
--   berisi tanggal mulai harga, artinya sistem POS sudah tracking perubahan
--   harga. Dengan Type 2, fact_transaksi_item bisa bergabung (JOIN) ke versi
--   harga yang tepat pada saat transaksi terjadi — bukan harga terkini.
--
-- Alternatif yang ditolak:
--   - Type 1 (overwrite): menghilangkan histori harga, rekonsiliasi nilai
--     transaksi lama menjadi tidak akurat.
--   - Type 0 (static): tidak mungkin karena harga memang berubah di data.
-- ============================================================
