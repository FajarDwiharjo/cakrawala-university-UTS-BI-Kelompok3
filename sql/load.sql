-- ============================================================
-- sql/load.sql - Urutan eksekusi warehouse T2 POS UMKM k8
-- Kelompok 3
-- Jalankan: python -m pipeline.load --topic t2 --slice k8 --twice
-- Strategi: CREATE OR REPLACE (full rebuild, idempoten)
-- ============================================================

-- ============================================================
-- 10_dim_date.sql - DIBERIKAN LENGKAP. Ini bukan checkpoint, ini alat.
-- Konformed dimension: SEMUA fact di warehouse ini menunjuk ke sini.
-- ============================================================

CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_sk,   -- kunci: YYYYMMDD, bukan urutan
       d AS full_date,
       CAST(year(d)  AS INTEGER) AS tahun,
       CAST(quarter(d) AS INTEGER) AS triwulan,
       CAST(month(d) AS INTEGER) AS bulan,
       strftime(d, '%B') AS nama_bulan,
       CAST(week(d)  AS INTEGER) AS pekan_iso,
       CAST(day(d)   AS INTEGER) AS hari,
       CAST(dayofweek(d) AS INTEGER) AS hari_ke,            -- 0 = Minggu
       strftime(d, '%A') AS nama_hari,
       CAST(dayofweek(d) IN (0, 6) AS BOOLEAN) AS akhir_pekan
FROM (SELECT unnest(generate_series(DATE '2024-01-01', DATE '2027-12-31', INTERVAL 1 DAY)) AS d);

-- Anggota Unknown: banyak pipeline gagal bukan karena datanya salah, tapi karena ada baris
-- yang tidak punya tanggal. Baris seperti itu tetap harus punya tempat.
INSERT INTO dim_date
SELECT -1, DATE '1900-01-01', 1900, 0, 0, 'TIDAK DIKETAHUI', 0, 0, -1, 'TIDAK DIKETAHUI', FALSE;


-- ============================================================
-- 20_dim_product.sql - Dimensi Produk (Entitas Utama)
-- Topik: T2 POS UMKM - Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- SCD Type: Type 2 â€” harga_satuan dan status aktif DAPAT BERUBAH
--   (produk bisa nonaktif atau berubah harga â€” histori harga penting
--    untuk rekonsiliasi nilai transaksi historis)
--
-- Kolom wajib:
--   * product_sk   : surrogate key (row_number, bukan ID sumber)
--   * product_id   : natural key / kunci bisnis dari sumber CSV
--   * valid_from, valid_to, is_current : Type 2 histori
-- ============================================================

CREATE OR REPLACE TABLE dim_product AS

-- â”€â”€ Snapshot aktif (satu baris per produk per periode harga) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
            )::DATE - INTERVAL 1 DAY
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

    -- status aktif dari sumber (ya/tidak) â†’ dinormalkan ke BOOLEAN
    CASE WHEN lower(trim(p.aktif)) = 'ya' THEN TRUE ELSE FALSE END   AS is_aktif

FROM read_csv_auto('data/raw/t2_umkm/products.csv', all_varchar=true) AS p

UNION ALL

-- â”€â”€ Anggota Unknown: transaksi tanpa product_id yang valid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Profiling: 1 FK orphan di transaction_items â†’ product_id tidak ada di products.csv
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
--   harga yang tepat pada saat transaksi terjadi â€” bukan harga terkini.
--
-- Alternatif yang ditolak:
--   - Type 1 (overwrite): menghilangkan histori harga, rekonsiliasi nilai
--     transaksi lama menjadi tidak akurat.
--   - Type 0 (static): tidak mungkin karena harga memang berubah di data.
-- ============================================================


-- ============================================================
-- 20_dim_outlet.sql - Dimensi Outlet (Referensi/Geografi)
-- Topik: T2 POS UMKM - Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- SCD Type: Type 1 â€” data outlet bersifat master referensi.
--   Nama, kota, dan tipe outlet bersifat deskriptif dan relatif stabil.
--   Jika ada koreksi (typo nama atau perubahan tipe), overwrite langsung
--   cukup karena analitik tidak butuh histori perubahan identitas outlet.
--   Status aktif di-overwrite pula (Type 1).
--
-- Catatan slice k8: 3 outlet (A, B, C) - 12 bulan data
-- ============================================================

CREATE OR REPLACE TABLE dim_outlet AS

-- â”€â”€ Baris dari sumber CSV outlets.csv â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

-- â”€â”€ Anggota Unknown: transaksi tanpa outlet_id yang dikenali â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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


-- ============================================================
-- 20_dim_status_transaksi.sql - Dimensi Status Transaksi (Kamus/Referensi)
-- Topik: T2 POS UMKM - Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- SCD Type: Type 0 â€” kode status bersifat tetap (tidak pernah berubah).
--   Status merupakan kamus domain yang didefinisikan sistem POS.
--   Profiling menunjukkan 5 varian status (dari kolom status di transactions.csv).
--   Nilai kode tidak akan berubah secara bisnis â€” Type 0 paling tepat.
-- ============================================================

CREATE OR REPLACE TABLE dim_status_transaksi AS

-- â”€â”€ Kamus status dari domain data profiling â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

-- â”€â”€ Anggota Unknown: transaksi dengan status di luar kamus â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
--   Menambah nilai analitik â€” analitik bisa filter WHERE kategori_final = 'selesai'
--   untuk menghitung pendapatan riil tanpa harus hafal semua kode status.
-- ============================================================


-- ============================================================
-- 30_fact_transaksi_item.sql - Fact Table Utama
-- Topik: T2 POS UMKM - Outlet A+B+C, 12 bulan (slice k8)
-- Kelompok 3
--
-- GRAIN: Satu baris = satu item produk yang terjual
--        dalam satu transaksi di satu outlet pada satu tanggal.
--
--        Lebih formal: satu baris mewakili penjualan (atau retur) satu
--        jenis produk (product_id) dalam satu faktur transaksi
--        (transaction_id) yang terjadi di satu outlet (outlet_id)
--        pada satu hari kalender (tanggal_waktu::date).
--
--        Natural key baris: (transaction_id, item_id)
--        â€” item_id adalah identifier per baris item dalam satu faktur
--          kombinasi keduanya unik di transaction_items.csv.
--
-- Aditivitas setiap measure:
--   qty             : ADDITIVE   â€” boleh di-SUM lintas semua dimensi
--                                  (total unit terjual per outlet, per produk, per bulan)
--   subtotal_rupiah : ADDITIVE   â€” boleh di-SUM (qty * harga_satuan - diskon)
--   diskon          : ADDITIVE   â€” boleh di-SUM (total potongan harga)
--   total_bayar_trx : SEMI-ADDITIVE â€” total bayar dari header transaksi
--                                  JANGAN di-SUM kalau JOIN ke item karena
--                                  akan double-count per baris item
--
-- Degenerate key:
--   transaction_id  : tidak punya dimensi sendiri, tetap di fact table
--   item_id         : identitas baris item, tidak punya dimensi sendiri
--
-- Dimensi yang TIDAK DIBANGUN:
--   dim_customer    : customers.csv ada di repo, namun transaction_items.csv
--                     tidak memiliki FK ke customer_id â€” analisis per pelanggan
--                     tidak dapat dilakukan dari grain ini tanpa JOIN tambahan
--                     ke transactions.csv yang memiliki customer_id.
--                     Keputusan ini dicatat di docs/D7_scope_cut.md.
-- ============================================================

CREATE OR REPLACE TABLE fact_transaksi_item AS

WITH items_dedup AS (
    SELECT
        transaction_id,
        item_id,
        product_id,
        qty,
        harga_satuan,
        diskon
    FROM read_csv_auto(
        'data/raw/t2_umkm/transaction_items.csv',
        all_varchar=true
    )
    GROUP BY
        transaction_id,
        item_id,
        product_id,
        qty,
        harga_satuan,
        diskon
),

transaction_check AS (
    SELECT
        transaction_id,
        COUNT(DISTINCT outlet_id) AS outlet_count,
        COUNT(DISTINCT tanggal_waktu) AS tanggal_count,
        COUNT(DISTINCT status) AS status_count,
        COUNT(DISTINCT total_bayar) AS total_bayar_count
    FROM read_csv_auto(
        'data/raw/t2_umkm/transactions.csv',
        all_varchar=true
    )
    GROUP BY transaction_id
),

transactions_clean AS (
    SELECT
        t.transaction_id,
        MIN(t.outlet_id) AS outlet_id,
        MIN(t.tanggal_waktu) AS tanggal_waktu,
        MIN(t.status) AS status,
        MIN(t.total_bayar) AS total_bayar
    FROM read_csv_auto(
        'data/raw/t2_umkm/transactions.csv',
        all_varchar=true
    ) AS t
    JOIN transaction_check AS c
        ON t.transaction_id = c.transaction_id
    WHERE c.outlet_count = 1
      AND c.tanggal_count = 1
      AND c.status_count = 1
      AND c.total_bayar_count = 1
    GROUP BY t.transaction_id
)

SELECT
    COALESCE(d.date_sk, -1) AS date_sk,
    COALESCE(p.product_sk, -1) AS product_sk,
    COALESCE(o.outlet_sk, -1) AS outlet_sk,
    COALESCE(s.status_sk, -1) AS status_sk,

    ti.transaction_id,
    ti.item_id,

    CAST(ti.qty AS INTEGER) AS qty,

    CAST(ti.harga_satuan AS DECIMAL(15,2))
        AS harga_satuan_aktual,

    CAST(ti.diskon AS DECIMAL(15,2))
        AS diskon,

    CAST(ti.qty AS INTEGER)
        * CAST(ti.harga_satuan AS DECIMAL(15,2))
        - CAST(ti.diskon AS DECIMAL(15,2))
        AS subtotal_rupiah,

    CAST(t.total_bayar AS DECIMAL(15,2))
        AS total_bayar_trx

FROM items_dedup AS ti

JOIN transactions_clean AS t
    ON ti.transaction_id = t.transaction_id

LEFT JOIN dim_date AS d
    ON d.full_date = CAST(t.tanggal_waktu AS DATE)

LEFT JOIN dim_product AS p
    ON p.product_id = ti.product_id
   AND CAST(t.tanggal_waktu AS DATE)
       BETWEEN p.valid_from AND p.valid_to

LEFT JOIN dim_outlet AS o
    ON o.outlet_id = t.outlet_id

LEFT JOIN dim_status_transaksi AS s
    ON s.status_code = UPPER(TRIM(t.status));

-- ============================================================
-- CATATAN DESAIN:
--
-- Grain (mengapa bukan per-transaksi?):
--   Memilih grain per-item memberikan fleksibilitas analitik tertinggi:
--   bisa roll-up ke per-transaksi, per-outlet, per-kategori, atau per-hari.
--   Grain per-transaksi akan menyembunyikan detail produk yang penting
--   untuk analisis bauran penjualan (mix analysis).
--
-- Mengapa total_bayar_trx SEMI-ADDITIVE?
--   Jika satu transaksi memiliki 3 baris item, total_bayar_trx muncul 3 kali
--   di fact table. SUM(total_bayar_trx) GROUP BY outlet akan overcount.
--   Gunakan SUM(subtotal_rupiah) untuk nilai penjualan per item.
--   Gunakan SUM(DISTINCT total_bayar_trx) atau COUNT(DISTINCT transaction_id)
--   hanya di level transaksi.
--
-- Duplikat transaction_id (profiling: 219 duplikat):
--   Duplicate header yang identik diringkas menjadi satu baris.
--   transaction_id dengan header yang berbeda tidak digunakan dalam fact
--   agar tidak menyebabkan multiple JOIN dan menggandakan baris fact.
-- ============================================================
