-- ============================================================
-- TUGAS TIM (D2 / UTS item 1.1, 1.2, 1.4) — fact table
-- Satu fact saja. Grain ditulis lengkap di komentar, bukan singkatan.
-- ============================================================

-- GRAIN: Satu baris = ______________________________________________.
--        (contoh bentuk benar: "satu desa pada satu slot prakiraan")
--
-- Setiap measure diberi label aditivitas + alasan:
--   ADDITIVE      : boleh di-SUM lintas semua dimensi  (contoh: qty, curah hujan mm)
--   SEMI-ADDITIVE : boleh di-SUM di sebagian dimensi   (contoh: saldo stok, flag siaga per waktu)
--   NON-ADDITIVE  : jangan di-SUM, pakai min/max/avg   (contoh: harga, suhu, persentase)

-- CATATAN: Untuk Kelompok 3 (T2 POS UMKM, slice k8), fact table utama
-- sudah diimplementasikan di: 30_fact_transaksi_item.sql
-- (grain: satu item produk per transaksi per outlet per tanggal)
-- File ini tidak dipakai — digantikan oleh implementasi yang lebih spesifik di atas.
