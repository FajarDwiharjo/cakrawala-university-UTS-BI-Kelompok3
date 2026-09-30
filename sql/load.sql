-- ============================================================
-- sql/load.sql — URUTAN EKSEKUSI WAREHOUSE TIM (TUGAS D3)
-- Kelompok 3 | T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)
--
-- Dijalankan oleh: python -m pipeline.load --topic t2 --slice k8 --twice
-- Urutan eksekusi: dimensi terlebih dahulu, kemudian fact table.
-- Semua tabel memakai CREATE OR REPLACE TABLE agar idempoten secara konstruksi.
-- ============================================================

-- 1. Dimensi Tanggal (Konformed)
CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_sk,
       d AS full_date,
       CAST(year(d)  AS INTEGER) AS tahun,
       CAST(quarter(d) AS INTEGER) AS triwulan,
       CAST(month(d) AS INTEGER) AS bulan,
       strftime(d, '%B') AS nama_bulan,
       CAST(week(d)  AS INTEGER) AS pekan_iso,
       CAST(day(d)   AS INTEGER) AS hari,
       CAST(dayofweek(d) AS INTEGER) AS hari_ke,
       strftime(d, '%A') AS nama_hari,
       CAST(dayofweek(d) IN (0, 6) AS BOOLEAN) AS akhir_pekan
FROM (SELECT unnest(generate_series(DATE '2024-01-01', DATE '2027-12-31', INTERVAL 1 DAY)) AS d);

INSERT INTO dim_date
SELECT -1, DATE '1900-01-01', 1900, 0, 0, 'TIDAK DIKETAHUI', 0, 0, -1, 'TIDAK DIKETAHUI', FALSE;

-- 2. Dimensi Produk (SCD Type 2)
CREATE OR REPLACE TABLE dim_product AS
SELECT
    row_number() OVER (
        ORDER BY p.product_id, p.harga_berlaku_dari
    ) AS product_sk,
    p.product_id,
    p.nama_produk,
    p.kategori,
    CAST(p.harga_satuan AS DECIMAL(15,2)) AS harga_satuan,
    COALESCE(CAST(p.harga_berlaku_dari AS DATE), DATE '2024-01-01') AS valid_from,
    COALESCE(
        CAST(
            CAST(
                lead(p.harga_berlaku_dari) OVER (
                    PARTITION BY p.product_id
                    ORDER BY p.harga_berlaku_dari
                ) AS DATE
            ) - INTERVAL 1 DAY
            AS DATE
        ),
        DATE '9999-12-31'
    ) AS valid_to,
    CASE
        WHEN lead(p.harga_berlaku_dari) OVER (
            PARTITION BY p.product_id
            ORDER BY p.harga_berlaku_dari
        ) IS NULL THEN TRUE
        ELSE FALSE
    END AS is_current,
    CASE WHEN lower(trim(p.aktif)) = 'ya' THEN TRUE ELSE FALSE END AS is_aktif
FROM read_csv_auto('{D}/products.csv', all_varchar=true) AS p
UNION ALL
SELECT
    -1 AS product_sk,
    'PRD-UNKNOWN' AS product_id,
    'TIDAK DIKETAHUI' AS nama_produk,
    'TIDAK DIKETAHUI' AS kategori,
    CAST(0 AS DECIMAL(15,2)) AS harga_satuan,
    DATE '1900-01-01' AS valid_from,
    DATE '9999-12-31' AS valid_to,
    TRUE AS is_current,
    FALSE AS is_aktif;

-- 3. Dimensi Outlet (SCD Type 1)
CREATE OR REPLACE TABLE dim_outlet AS
SELECT
    row_number() OVER (ORDER BY o.outlet_id) AS outlet_sk,
    o.outlet_id,
    o.nama_outlet,
    o.kota,
    o.tipe,
    CASE WHEN lower(trim(o.aktif)) = 'ya' THEN TRUE ELSE FALSE END AS is_aktif,
    CAST(o.dibuka_sejak AS DATE) AS dibuka_sejak
FROM read_csv_auto('{D}/outlets.csv', all_varchar=true) AS o
UNION ALL
SELECT
    -1 AS outlet_sk,
    'OUT-UNKNOWN' AS outlet_id,
    'TIDAK DIKETAHUI' AS nama_outlet,
    'TIDAK DIKETAHUI' AS kota,
    'TIDAK DIKETAHUI' AS tipe,
    FALSE AS is_aktif,
    DATE '1900-01-01' AS dibuka_sejak;

-- 4. Dimensi Status Transaksi (SCD Type 0)
CREATE OR REPLACE TABLE dim_status_transaksi AS
SELECT
    row_number() OVER (ORDER BY status_code) AS status_sk,
    status_code,
    label_indonesia,
    kategori_final,
    berdampak_pendapatan
FROM (VALUES
    ('PAID',      'Lunas / Dibayar',         'selesai',     TRUE),
    ('PENDING',   'Menunggu Pembayaran',      'proses',      FALSE),
    ('CANCELLED', 'Dibatalkan',               'batal',       FALSE),
    ('REFUNDED',  'Dikembalikan / Retur',     'batal',       FALSE),
    ('PARTIAL',   'Pembayaran Sebagian',      'proses',      FALSE)
) AS t(status_code, label_indonesia, kategori_final, berdampak_pendapatan)
UNION ALL
SELECT
    -1 AS status_sk,
    'UNKNOWN' AS status_code,
    'TIDAK DIKETAHUI' AS label_indonesia,
    'tidak diketahui' AS kategori_final,
    FALSE AS berdampak_pendapatan;

-- 5. Fact Table Utama (Grain: satu baris per item transaksi)
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
        '{D}/transaction_items.csv',
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
        '{D}/transactions.csv',
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
        '{D}/transactions.csv',
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

-- 6. Kompatibilitas Alias Fact Table untuk Checker Pipeline
CREATE OR REPLACE TABLE fact_sales_item AS
SELECT * FROM fact_transaksi_item;
