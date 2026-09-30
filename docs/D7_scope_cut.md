# D7 — Batas lingkup capstone (ditandatangani di Sesi 8)

> Diisi tim **sebelum** menghadap dosen. Dosen hanya mencoret dan tanda tangan.
> Form ini yang jadi acuan rubrik di Sesi 15–16: yang kamu potong tidak dihitung sebagai kekurangan.

Tim: Kelompok 3 &nbsp;&nbsp; Topik / slice: K3T2 POS UMKM — Outlet A+B+C, 12 bulan (k8) &nbsp;&nbsp; Tanggal: 28 Sept 2026

## AKAN DIBANGUN (maksimal 1 fact table + 1 conformed dimension per RPS butir 8)

| # | Artefak | Ukuran selesai | Deadline |
|---|---|---|---|
| 1 | fact: `fact_transaksi_item` — satu item produk per transaksi per outlet per tanggal | Grain terdokumentasi di DDL; baris fact = item unik (transaction_id, item_id) setelah dedup; tiap measure berlabel aditivitas | 2 Sept 2026 |
| 2 | dim: `dim_date` (conformed) — dimensi tanggal YYYYMMDD | 1.461 baris (2024–2027) + 1 unknown | 2 Sept 2026 |
| 3 | dim: `dim_product` (SCD Type 2) — histori harga per produk | 120 produk, 9 varian harga, valid_from/valid_to/is_current | 2 Sept 2026 |
| 4 | dim: `dim_outlet` (SCD Type 1) — master outlet A+B+C | 3 outlet + 1 unknown (OUT-D tutup, di luar slice) | 2 Sept 2026 |
| 5 | dim: `dim_status_transaksi` (SCD Type 0) — kamus status POS | Status sesuai nilai nyata di data + 1 unknown | 2 Sept 2026 |
| 6 | 3 kueri analitik `sql/40_analytics/q01..q03` — tren MoM (window/CTE), retur per triwulan, ukuran keranjang | Berjalan tanpa error di warehouse tim, jawaban 1 kalimat tertulis | 2 Sept 2026 |

## TIDAK LAGI DIBANGUN (sebut namanya, jangan "kalau ada waktu")

| # | Yang dicabut | Alasan |
|---|---|---|
| 1 | `dim_customer` — dimensi pelanggan dari customers.csv | `transaction_items.csv` tidak punya FK ke `customer_id`; 25% transaksi anonim; membangun dim_customer tidak mengubah grain fact dan tidak bisa disambungkan tanpa mengubah desain fact. Analisis pelanggan dikecualikan dari scope. |
| 2 | `dim_kategori` sebagai dimensi mandiri | Kolom `kategori` sudah ada di `dim_product`; membuat tabel dimensi terpisah tidak menambah nilai analitik dan hanya menambah jumlah JOIN tanpa manfaat signifikan. |

## Tanda tangan

| Tim | Dosen |
|---|---|
| Kelompok 3 — Sisilia Fransisca, Navrosjo, Zainuddin, Fajar Dwi Harjo | &nbsp; |
| [tanda tangan] | [tanda tangan] |
