# D6 — Kamus metrik (12 field)

## Metrik 1 — Omzet Harian per Outlet

| # | Field | Isi |
|---|---|---|
| 1 | Nama metrik | omzet_harian_outlet |
| 2 | Definisi | Total nilai penjualan bersih (penjualan dikurangi diskon dan retur item) dari transaksi yang sudah lunas di satu outlet dalam satu hari kalender. |
| 3 | Rumus (SQL) | `SUM(subtotal_rupiah)` dari fact_transaksi_item, difilter `kategori_final = 'selesai'`. Lengkap di sql/50_metrics/m01_omzet_harian.sql |
| 4 | Grain | 1 baris per tanggal (WIB) per outlet |
| 5 | Tabel sumber | fact_transaksi_item, dim_date, dim_outlet, dim_status_transaksi |
| 6 | Owner | Manajer Operasional Outlet |
| 7 | Time basis | Per hari kalender WIB (Asia/Jakarta). Timestamp berakhiran Z di sumber adalah UTC dan harus dikonversi dulu. |
| 8 | Satuan | Rupiah |
| 9 | Dimensi yang boleh dipotong | Tanggal/bulan/tahun (dim_date), outlet (dim_outlet), produk (dim_product), status (dim_status_transaksi). Tidak boleh per pelanggan karena dim_customer tidak dibangun (lihat D7). |
| 10 | Filter default | Hanya transaksi berstatus PAID (`kategori_final = 'selesai'`). PENDING, PARTIAL, CANCELLED, REFUNDED, dan status tidak dikenal tidak ikut. `total_bayar_trx` tidak pernah dijumlahkan. |
| 11 | Arti nilai kosong | Tidak ada data. Hari tanpa baris fact tidak muncul, dan data tidak bisa membedakan outlet libur dari data yang hilang, jadi tidak ditulis sebagai 0. |
| 12 | Versi | v1, berlaku 2026-09-30 |

### Cara metrik ini di-gaming
Satu penjualan dicatat dua kali dengan `transaction_id` yang sama, sehingga omzet outlet tampak naik tanpa ada penjualan tambahan. Profiling menemukan 219 `transaction_id` ganda di sumber, jadi ini bukan skenario khayalan.

### Guard test-nya
`transaksi_id_unik` di `tests/test_definitions.yml`: menangkap `transaction_id` yang muncul lebih dari sekali sebelum masuk fact.