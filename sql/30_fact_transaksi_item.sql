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
--        — item_id adalah identifier per baris item dalam satu faktur;
--          kombinasi keduanya unik di transaction_items.csv.
--
-- Aditivitas setiap measure:
--   qty             : ADDITIVE   — boleh di-SUM lintas semua dimensi
--                                  (total unit terjual per outlet, per produk, per bulan)
--   subtotal_rupiah : ADDITIVE   — boleh di-SUM (qty * harga_satuan - diskon)
--   diskon          : ADDITIVE   — boleh di-SUM (total potongan harga)
--   total_bayar_trx : SEMI-ADDITIVE — total bayar dari header transaksi;
--                                  JANGAN di-SUM kalau JOIN ke item karena
--                                  akan double-count per baris item
--
-- Degenerate key:
--   transaction_id  : tidak punya dimensi sendiri, tetap di fact table
--   item_id         : identitas baris item, tidak punya dimensi sendiri
--
-- Dimensi yang TIDAK DIBANGUN:
--   dim_customer    : customers.csv ada di repo, namun transaction_items.csv
--                     tidak memiliki FK ke customer_id — analisis per pelanggan
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
