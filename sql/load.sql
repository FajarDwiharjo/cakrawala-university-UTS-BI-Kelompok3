-- ============================================================
-- sql/load.sql — URUTAN EKSEKUSI MILIK TIM (TUGAS D3)
-- Isi dengan perintah yang membangun warehouse dari nol, dalam urutan yang benar.
-- Jalankan:  python -m pipeline.load --topic t3 --slice k1 --twice
--
-- Aturan urutan: dimensi dulu (kecuali dim_date), fact terakhir.
-- Setiap tabel ditulis dengan CREATE OR REPLACE ... AS SELECT (idempoten secara konstruksi).
-- Kalau memilih strategi lain (upsert / DELETE partisi), tulis di pipeline/DESIGN_load.md
-- dan jelaskan kenapa dan kapan strategi itu bisa menggandakan baris.
--
-- Placeholder di bawah ini SENGAJA bertanda TODO supaya loader menolak jalan sampai kamu isi.
-- ============================================================

SOURCE sql/10_dim_date.sql;
SOURCE sql/20_dim_product.sql;
SOURCE sql/20_dim_outlet.sql;
SOURCE sql/20_dim_status_transaksi.sql;
SOURCE sql/30_fact_transaksi_item.sql;