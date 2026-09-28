# D7 — Batas lingkup capstone (ditandatangani di Sesi 8)

> Diisi tim **sebelum** menghadap dosen. Dosen hanya mencoret dan tanda tangan.
> Form ini yang jadi acuan rubrik di Sesi 15–16: yang kamu potong tidak dihitung sebagai kekurangan.

Tim: Kelompok 3 Topik / slice: K3T2 POS UMKM — Outlet A+B+C, 12 bulank8  Tanggal: 28 Sept 2026

## AKAN DIBANGUN (maksimal 1 fact table + 1 conformed dimension per RPS butir 8)

| # | Artefak | Ukuran selesai | Deadline |
|---|---|---|---|
| 1 | dim: `dim_date` (conformed) — dimensi tanggal YYYYMMDD | 1.461 baris (2024–2027) + 1 unknown | 2 Okt 2026 |
| 2 | dim: `dim_product` (SCD Type 2) — histori harga per produk | 120 produk, 9 varian harga, valid_from/valid_to/is_current | 2 Okt 2026 |
| 3 | dim: `dim_outlet` (SCD Type 1) — master outlet A+B+C | 3 outlet + 1 unknown | 2 Okt 2026 |
| 4 | dim: `dim_status_transaksi` (SCD Type 0) — kamus 5 status POS | 5 status + 1 unknown | 2 Okt 2026 |
| 5 | grain: definisi grain `fact_transaksi_item` — satu item produk per transaksi per outlet per tanggal | Terdokumentasi di DDL + README.md | 2 Okt 2026 |

## TIDAK LAGI DIBANGUN (sebut namanya, jangan "kalau ada waktu")

| # | Yang dicabut | Alasan |
|---|---|---|
| 1 |  |  |
| 2 |  |  |

## Tanda tangan

| Tim | Dosen |
|---|---|
|  |  |
| [tanda tangan] | [tanda tangan] |
