# D7 — Batas lingkup capstone (ditandatangani di Sesi 8)

> Diisi tim **sebelum** menghadap dosen. Dosen hanya mencoret dan tanda tangan.
> Form ini yang jadi acuan rubrik di Sesi 15–16: yang kamu potong tidak dihitung sebagai kekurangan.

<<<<<<< HEAD
Tim: Kelompok 3 | Topik / slice: K3T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8) | Tanggal: 28 Sept 2026
=======
Tim: Kelompok 3 &nbsp;&nbsp; Topik / slice: K3T2 POS UMKM — Outlet A+B+C, 12 bulan (k8) &nbsp;&nbsp; Tanggal: 28 Sept 2026
>>>>>>> 86ae7ce2b95f18968db6ee9fc2e6355f12412be2

## AKAN DIBANGUN (maksimal 1 fact table + 1 conformed dimension per RPS butir 8)

| # | Artefak | Ukuran selesai | Deadline |
|---|---|---|---|
<<<<<<< HEAD
| 1 | fact: `fact_transaksi_item` — satu item produk per transaksi per outlet per tanggal | Grain terdokumentasi di DDL; baris fact = item unik (transaction_id, item_id) setelah dedup; tiap measure berlabel aditivitas | 30 Sept 2026 |
| 2 | dim: `dim_date` (conformed) — dimensi tanggal YYYYMMDD | 1.461 baris (2024–2027) + 1 unknown | 30 Sept 2026 |
| 3 | dim: `dim_product` (SCD Type 2) — histori harga per produk | 120 produk, 9 varian harga, valid_from/valid_to/is_current | 30 Sept 2026 |
| 4 | dim: `dim_outlet` (SCD Type 1) — master outlet A+B+C | 3 outlet + 1 unknown (OUT-D tutup, di luar slice) | 30 Sept 2026 |
| 5 | dim: `dim_status_transaksi` (SCD Type 0) — kamus status POS | Status sesuai nilai nyata di data + 1 unknown | 30 Sept 2026 |
| 6 | 3 kueri analitik `sql/40_analytics/q01..q03` — tren MoM (window/CTE), retur per triwulan, ukuran keranjang | Berjalan tanpa error di warehouse tim, jawaban 1 kalimat tertulis | 30 Sept 2026 |
=======
| 1 | **fact:** `fact_transaksi_item` (`sql/30_fact_transaksi_item.sql`) — satu item produk per transaksi per outlet per tanggal | Natural key `(transaction_id, item_id)`; dedup header transaksi duplikat (219 kasus); 4 surrogate key: `date_sk`, `product_sk`, `outlet_sk`, `status_sk`; 4 measure berlabel aditivitas (`qty` ADDITIVE, `subtotal_rupiah` ADDITIVE, `diskon` ADDITIVE, `total_bayar_trx` SEMI-ADDITIVE); anggota unknown via `COALESCE(..., -1)` | 28 Sept 2026 |
| 2 | **dim:** `dim_date` (`sql/10_dim_date.sql`) — conformed, generator tanggal YYYYMMDD | 1.461 baris (2024-01-01 s.d. 2027-12-31) + 1 baris unknown (`date_sk = -1`); kolom: `date_sk`, `full_date`, `tahun`, `triwulan`, `bulan`, `nama_bulan`, `pekan_iso`, `hari`, `hari_ke`, `nama_hari`, `akhir_pekan` | 28 Sept 2026 |
| 3 | **dim:** `dim_product` (`sql/20_dim_product.sql`) — SCD Type 2, histori harga per produk | Natural key: `product_id + harga_berlaku_dari`; kolom SCD: `valid_from`, `valid_to`, `is_current`; surrogate key `product_sk` via `row_number()`; 1 anggota unknown (`product_sk = -1`, menampung 1 FK orphan dari profiling); reason: harga berubah — histori wajib untuk rekonsiliasi nilai transaksi lama | 28 Sept 2026 |
| 4 | **dim:** `dim_outlet` (`sql/20_dim_outlet.sql`) — SCD Type 1, master outlet A+B+C | 3 outlet aktif + 1 unknown (`outlet_sk = -1`); natural key: `outlet_id`; kolom: `nama_outlet`, `kota`, `tipe`, `is_aktif`, `dibuka_sejak`; OUT-D dikecualikan (tutup, di luar slice k8) | 28 Sept 2026 |
| 5 | **dim:** `dim_status_transaksi` (`sql/20_dim_status_transaksi.sql`) — SCD Type 0, kamus status POS | 5 kode status (PAID, PENDING, CANCELLED, REFUNDED, PARTIAL) + 1 unknown; kolom tambahan: `label_indonesia`, `kategori_final`, `berdampak_pendapatan` untuk kemudahan filter analitik | 28 Sept 2026 |
| 6 | **3 kueri analitik** (`sql/40_analytics/q01..q03`) | **q01** — ukuran keranjang: item/transaksi & nilai/transaksi, hari kerja vs akhir pekan (filter PAID, outlet A+B+C, 2025); **q02** — tren omzet bersih bulanan MoM per outlet (CTE + window `LAG`, `RANK`); **q03** — tingkat retur (qty negatif) per outlet per triwulan (agregasi `FILTER`); masing-masing dilengkapi jawaban 1 kalimat | 28 Sept 2026 |
| 7 | **Kamus metrik** (`docs/kamus_metrik.md`) — Metrik 1: Omzet Bersih Bulanan per Outlet | 12 field terisi: nama, definisi, rumus SQL, grain, tabel sumber, owner, time basis, satuan, dimensi potong, filter default, arti kosong, versi; dilengkapi cara gaming & guard test SQL | 28 Sept 2026 |
| 8 | **SQL metrik** (`sql/50_metrics/omzet_bersih_bulanan.sql`) | Query sesuai kamus: `SUM(subtotal_rupiah)` GROUP BY outlet × bulan, filter PAID + outlet A+B+C + 2025; kolom bantu audit (jumlah_transaksi, jumlah_baris_item, jumlah_baris_retur) | 28 Sept 2026 |
| 9 | **Desain load** (`pipeline/DESIGN_load.md`) — strategi idempoten & dependency | 5 tabel dengan strategi `CREATE OR REPLACE` (full rebuild); natural key, kolom partisi, analisis risiko duplikasi, urutan dependency didokumentasikan; `load.sql` berisi urutan eksekusi 5 SQL | 28 Sept 2026 |
| 10 | **6 test kualitas data** (`tests/test_definitions.yml`, topic: t2) | `transaction_id_duplikat` (blocking, fail, 219 baris); `item_fk_orphan` (blocking, fail, 1 baris); `timestamp_utc_tanpa_zona` (warning, fail, 2.389 baris); `transaksi_tanpa_item` (warning, fail, 158 baris); `qty_negatif_bukan_refund` (warning, fail, 621 baris); `harga_satuan_tidak_positif` (blocking, pass, 0 baris); semua punya severity + justifikasi | 28 Sept 2026 |
| 11 | **Profil data** (`docs/profile_t2_k8.md`) — D1 data profiling T2 k8 | Profiling 5 CSV sumber; temuan kualitas: duplikat transaction_id, FK orphan, format timestamp UTC/lokal campuran, transaksi tanpa item, qty negatif non-retur | 28 Sept 2026 |
| 12 | **Batasan desain** (`docs/Batasan_desain.md`) — D12 | Pertanyaan yang tidak bisa dijawab (analisis pelanggan berulang); alasan: FK orphan, 25% transaksi anonim, definisi bisnis belum disepakati; kebutuhan teknis jika ingin ditambahkan di masa depan | 28 Sept 2026 |
>>>>>>> 86ae7ce2b95f18968db6ee9fc2e6355f12412be2

## TIDAK LAGI DIBANGUN (sebut namanya, jangan "kalau ada waktu")

| # | Yang dicabut | Alasan |
|---|---|---|
<<<<<<< HEAD
| 1 | Dimensi `dim_customer` | Sekitar 25% transaksi anonim (tanpa customer_id), dan grain fact adalah item transaksi; kelompok memfokuskan star schema pada 1 fact + 1 conformed dimension per batasan RPS butir 8. |
| 2 | Analisis pelanggan berulang (repeat purchase / RFM) | Karena `dim_customer` dan kunci `customer_sk` tidak dibawa ke `fact_transaksi_item`, pertanyaan bisnis mengenai retensi pelanggan sengaja dipotong (terdokumentasi di `docs/Batasan_desain.md`). |
| 3 | Tabel dimensi `dim_kategori` terpisah | Kategori produk didenormalisasi langsung menjadi kolom deskriptif di `dim_product` untuk menghindari kompleksitas snowflake schema yang tidak diperlukan. |
| 4 | Data historis Outlet D (`OUT-D`) | Outlet D telah ditutup secara permanen dan berada di luar cakupan slice k8 yang disepakati (hanya mencakup Outlet A, B, dan C). |
=======
| 1 | `dim_customer` — dimensi pelanggan dari `customers.csv` | `transaction_items.csv` tidak punya FK ke `customer_id`; ±25% transaksi di `transactions.csv` tidak memiliki `customer_id` (anonim); membangun dimensi ini tidak mengubah grain `fact_transaksi_item` karena kunci pelanggan tidak bisa dibawa ke level item. Analisis per pelanggan dikecualikan dari scope k8. |
| 2 | `dim_kategori` — dimensi kategori produk terpisah | Kolom `kategori` sudah ada sebagai atribut di `dim_product`; kueri analitik bisa langsung `JOIN dim_product` dan filter/group by `kategori` tanpa dimensi tambahan. Membuat tabel terpisah hanya menambah jumlah JOIN tanpa nilai analitik baru. |
>>>>>>> 86ae7ce2b95f18968db6ee9fc2e6355f12412be2

## Tanda tangan

| Tim (Kelompok 3) | Dosen Pembimbing |
|---|---|
<<<<<<< HEAD
| Sisilia Fransisca (Ketua Kelompok 3) | Tim Dosen Pengampu SDA2161 |
| [tanda tangan digital terverifikasi] | [tanda tangan disetujui Sesi 8] |
=======
|  |  |
>>>>>>> 86ae7ce2b95f18968db6ee9fc2e6355f12412be2
