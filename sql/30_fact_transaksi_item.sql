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

SELECT
    -- ── Surrogate keys → FK ke setiap dimensi (star schema, bukan snowflake) ──

    -- FK ke dim_date (date_sk = YYYYMMDD integer)
    COALESCE(
        d.date_sk,
        -1
    )                                               AS date_sk,

    -- FK ke dim_product (Type 2: cocokkan tanggal transaksi ke versi harga yg berlaku)
    COALESCE(
        p.product_sk,
        -1
    )                                               AS product_sk,

    -- FK ke dim_outlet
    COALESCE(
        o.outlet_sk,
        -1
    )                                               AS outlet_sk,

    -- FK ke dim_status_transaksi
    COALESCE(
        s.status_sk,
        -1
    )                                               AS status_sk,

    -- ── Degenerate keys (tidak ada dimensi sendiri) ──────────────────────────
    ti.transaction_id,          -- degenerate: nomor faktur transaksi
    ti.item_id,                 -- degenerate: nomor baris item

    -- ── Measures ─────────────────────────────────────────────────────────────

    -- ADDITIVE: jumlah unit item (negatif = retur; profiling: 628 qty negatif)
    CAST(ti.qty AS INTEGER)                          AS qty,

    -- ADDITIVE: harga satuan yang dipakai saat transaksi (dari fact, bukan dari dim)
    CAST(ti.harga_satuan AS DECIMAL(15,2))           AS harga_satuan_aktual,

    -- ADDITIVE: potongan harga per item (diskon = 0 jika tidak ada)
    CAST(ti.diskon AS DECIMAL(15,2))                 AS diskon,

    -- ADDITIVE: subtotal rupiah = qty * harga_satuan - diskon
    --           (bisa negatif untuk baris retur)
    CAST(ti.qty AS INTEGER)
        * CAST(ti.harga_satuan AS DECIMAL(15,2))
        - CAST(ti.diskon AS DECIMAL(15,2))           AS subtotal_rupiah,

    -- SEMI-ADDITIVE: total_bayar adalah nilai header transaksi
    --               JANGAN di-SUM kalau dimensi analisis adalah per item
    --               (akan double-count bila satu transaksi punya banyak item)
    CAST(t.total_bayar AS DECIMAL(15,2))             AS total_bayar_trx

FROM read_csv_auto('data/raw/t2_umkm/transaction_items.csv', all_varchar=true) AS ti

-- JOIN ke transactions (header transaksi → outlet, status, tanggal, total bayar)
JOIN read_csv_auto('data/raw/t2_umkm/transactions.csv', all_varchar=true) AS t
    ON ti.transaction_id = t.transaction_id

-- JOIN ke dim_date (konform dimensi tanggal)
LEFT JOIN dim_date AS d
    ON d.full_date = CAST(t.tanggal_waktu AS DATE)

-- JOIN ke dim_product (Type 2: cocokkan versi harga pada tanggal transaksi)
LEFT JOIN dim_product AS p
    ON  p.product_id = ti.product_id
    AND CAST(t.tanggal_waktu AS DATE) >= p.valid_from
    AND CAST(t.tanggal_waktu AS DATE) <= p.valid_to

-- JOIN ke dim_outlet (Type 1: selalu versi terkini)
LEFT JOIN dim_outlet AS o
    ON o.outlet_id = t.outlet_id

-- JOIN ke dim_status_transaksi (Type 0: kamus statis)
LEFT JOIN dim_status_transaksi AS s
    ON s.status_code = t.status;

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
--   Duplikat di transactions.csv akan menyebabkan multiple JOIN ke fact.
--   Test kualitas wajib menangkap ini (lihat tests/test_definitions.yml).
-- ============================================================
