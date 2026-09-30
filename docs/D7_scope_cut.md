# D7 — Batas lingkup capstone (ditandatangani di Sesi 8)

> Diisi tim **sebelum** menghadap dosen. Dosen hanya mencoret dan tanda tangan.
> Form ini yang jadi acuan rubrik di Sesi 15–16: yang kamu potong tidak dihitung sebagai kekurangan.

Tim: Kelompok 3 | Topik / slice: K3T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8) | Tanggal: 28 Sept 2026

## AKAN DIBANGUN (maksimal 1 fact table + 1 conformed dimension per RPS butir 8)

| # | Artefak | Ukuran selesai | Deadline |
|---|---|---|---|
| 1 | fact: `fact_transaksi_item` — satu item produk per transaksi per outlet per tanggal | Grain terdokumentasi di DDL; baris fact = item unik (transaction_id, item_id) setelah dedup; tiap measure berlabel aditivitas | 30 Sept 2026 |
| 2 | dim: `dim_date` (conformed) — dimensi tanggal YYYYMMDD | 1.461 baris (2024–2027) + 1 unknown | 30 Sept 2026 |
| 3 | dim: `dim_product` (SCD Type 2) — histori harga per produk | 120 produk, 9 varian harga, valid_from/valid_to/is_current | 30 Sept 2026 |
| 4 | dim: `dim_outlet` (SCD Type 1) — master outlet A+B+C | 3 outlet + 1 unknown (OUT-D tutup, di luar slice) | 30 Sept 2026 |
| 5 | dim: `dim_status_transaksi` (SCD Type 0) — kamus status POS | Status sesuai nilai nyata di data + 1 unknown | 30 Sept 2026 |
| 6 | 3 kueri analitik `sql/40_analytics/q01..q03` — tren MoM (window/CTE), retur per triwulan, ukuran keranjang | Berjalan tanpa error di warehouse tim, jawaban 1 kalimat tertulis | 30 Sept 2026 |

## TIDAK LAGI DIBANGUN (sebut namanya, jangan "kalau ada waktu")

| # | Yang dicabut | Alasan |
|---|---|---|
| 1 | Dimensi `dim_customer` | Sekitar 25% transaksi anonim (tanpa customer_id), dan grain fact adalah item transaksi; kelompok memfokuskan star schema pada 1 fact + 1 conformed dimension per batasan RPS butir 8. |
| 2 | Analisis pelanggan berulang (repeat purchase / RFM) | Karena `dim_customer` dan kunci `customer_sk` tidak dibawa ke `fact_transaksi_item`, pertanyaan bisnis mengenai retensi pelanggan sengaja dipotong (terdokumentasi di `docs/Batasan_desain.md`). |
| 3 | Tabel dimensi `dim_kategori` terpisah | Kategori produk didenormalisasi langsung menjadi kolom deskriptif di `dim_product` untuk menghindari kompleksitas snowflake schema yang tidak diperlukan. |
| 4 | Data historis Outlet D (`OUT-D`) | Outlet D telah ditutup secara permanen dan berada di luar cakupan slice k8 yang disepakati (hanya mencakup Outlet A, B, dan C). |