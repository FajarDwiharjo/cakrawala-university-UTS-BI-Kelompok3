# D6 — Kamus Metrik (12 Field)

> **Catatan Kurikulum:** UTS item 5 menilai minimal satu metrik lengkap; UAS menilai tiga metrik. Setiap metrik wajib memiliki implementasi berkas SQL di folder `sql/50_metrics/` yang terbukti dapat dieksekusi pada data warehouse.

---

## Metrik 1 — Omzet Harian per Outlet

| # | Field | Isi |
|---|---|---|
| 1 | **Nama metrik** | `omzet_harian_outlet` |
| 2 | **Definisi** | Total nilai penjualan bersih (penjualan dikurangi diskon dan retur item) dari transaksi yang sudah lunas di satu outlet dalam satu hari kalender. |
| 3 | **Rumus (SQL)** | `SUM(subtotal_rupiah)` dari `fact_transaksi_item`, difilter `kategori_final = 'selesai'`. Implementasi lengkap di `sql/50_metrics/m01_omzet_harian.sql`. |
| 4 | **Grain** | 1 baris per tanggal (WIB) per outlet |
| 5 | **Tabel sumber** | `fact_transaksi_item`, `dim_date`, `dim_outlet`, `dim_status_transaksi` |
| 6 | **Owner** | Manajer Operasional Outlet |
| 7 | **Time basis** | Per hari kalender WIB (Asia/Jakarta). Timestamp berakhiran Z di sumber adalah UTC dan dikonversi ke tanggal lokal. |
| 8 | **Satuan** | Rupiah (IDR) |
| 9 | **Dimensi yang boleh dipotong** | Tanggal/bulan/tahun (`dim_date`), outlet (`dim_outlet`), produk (`dim_product`), status (`dim_status_transaksi`). Tidak boleh per pelanggan karena `dim_customer` tidak dibangun (lihat D7). |
| 10 | **Filter default** | Hanya transaksi berstatus PAID (`kategori_final = 'selesai'`). PENDING, PARTIAL, CANCELLED, REFUNDED tidak dihitung sebagai omzet. Kolom `total_bayar_trx` tidak pernah dijumlahkan (semi-additive). |
| 11 | **Arti nilai kosong** | Tidak ada data. Tanggal tanpa transaksi tidak dimunculkan, data tidak membedakan outlet libur dari kehilangan data sehingga tidak ditulis sebagai 0. |
| 12 | **Versi** | v1, berlaku 2026-09-30 |

### Cara metrik ini di-gaming
Satu transaksi penjualan dicatat berulang kali dengan `transaction_id` yang sama, sehingga omzet outlet tampak naik tanpa penambahan transaksi nyata. Berdasarkan data profiling pada `transactions.csv`, ditemukan 219 transaksi duplikat sehingga skenario ini sangat berisiko terjadi jika tidak ada deduplikasi.

### Guard test-nya
Test `transaction_id_duplikat` di `tests/test_definitions.yml`: menangkap transaksi yang muncul lebih dari satu kali sebelum masuk ke fact table.

---

## Metrik 2 — Pertumbuhan Omzet Bulanan per Outlet (MoM Growth)

| # | Field | Isi |
|---|---|---|
| 1 | **Nama metrik** | `pertumbuhan_mom_omzet` |
| 2 | **Definisi** | Persentase kenaikan atau penurunan omzet penjualan bersih lunas (PAID) pada outlet di bulan berjalan dibandingkan dengan omzet bulan sebelumnya. |
| 3 | **Rumus (SQL)** | `ROUND(100.0 * (omzet_bersih - LAG(omzet_bersih) OVER (PARTITION BY outlet_id ORDER BY tahun, bulan)) / NULLIF(LAG(omzet_bersih) OVER (PARTITION BY outlet_id ORDER BY tahun, bulan), 0), 1)` dengan `omzet_bersih = SUM(subtotal_rupiah)`. Lengkap di `sql/50_metrics/m02_pertumbuhan_mom.sql`. |
| 4 | **Grain** | 1 baris per bulan kalender per outlet |
| 5 | **Tabel sumber** | `fact_transaksi_item`, `dim_date`, `dim_outlet`, `dim_status_transaksi` |
| 6 | **Owner** | General Manager / Divisi Keuangan Retail |
| 7 | **Time basis** | Per bulan kalender (tahun, bulan dari `dim_date`). |
| 8 | **Satuan** | Persen (%) |
| 9 | **Dimensi yang boleh dipotong** | Outlet (`dim_outlet`), tahun dan bulan (`dim_date`). Tidak boleh dipotong per pelanggan. |
| 10 | **Filter default** | Transaksi berstatus `PAID` (`kategori_final = 'selesai'`), outlet aktif slice k8 (`OUT-A`, `OUT-B`, `OUT-C`), tahun 2025. |
| 11 | **Arti nilai kosong** | `NULL` untuk bulan pertama (Januari 2025) karena tidak memiliki periode bulan sebelumnya sebagai basis pembanding. |
| 12 | **Versi** | v1, berlaku 2026-09-30 |

### Cara metrik ini di-gaming
Memanipulasi pencatatan tanggal transaksi di akhir bulan (menunda atau memajukan tanggal pembukuan) atau menahan proses refund barang hingga pergantian bulan agar pertumbuhan MoM bulan tertentu tampak tinggi dan memenuhi target bulanan.

### Guard test-nya
Test `timestamp_utc_tanpa_zona` di `tests/test_definitions.yml`: mendeteksi timestamp UTC tanpa zona waktu agar penetapan tanggal/bulan transaksi tidak bergeser hingga 7 jam dan tidak mendistorsi batas cut-off bulanan.

---

## Metrik 3 — Rasio Retur Barang Triwulanan per Outlet

| # | Field | Isi |
|---|---|---|
| 1 | **Nama metrik** | `rasio_retur_triwulan` |
| 2 | **Definisi** | Proporsi persentase baris item transaksi yang merupakan retur barang (kuantitas negatif) terhadap keseluruhan baris item yang tercatat di suatu outlet dalam periode satu triwulan. |
| 3 | **Rumus (SQL)** | `ROUND(100.0 * COUNT(*) FILTER (WHERE qty < 0) / COUNT(*), 2)` dari baris `fact_transaksi_item`. Lengkap di `sql/50_metrics/m03_rasio_retur.sql`. |
| 4 | **Grain** | 1 baris per triwulan kalender per outlet |
| 5 | **Tabel sumber** | `fact_transaksi_item`, `dim_date`, `dim_outlet` |
| 6 | **Owner** | Manajer Quality Control & Pengendalian Persediaan |
| 7 | **Time basis** | Per triwulan kalender (Q1, Q2, Q3, Q4) dari `dim_date.triwulan`. |
| 8 | **Satuan** | Persen (%) |
| 9 | **Dimensi yang boleh dipotong** | Outlet (`dim_outlet`), triwulan/tahun (`dim_date`), produk/kategori (`dim_product`). |
| 10 | **Filter default** | Outlet A+B+C, tahun kalender 2025. Tidak memfilter status transaksi karena retur melekat pada baris item dengan `qty < 0`. |
| 11 | **Arti nilai kosong** | 0.00% jika dalam satu triwulan suatu outlet tidak memiliki item retur sama sekali. |
| 12 | **Versi** | v1, berlaku 2026-09-30 |

### Cara metrik ini di-gaming
Kasir atau staf outlet tidak mencatat barang rusak/dikembalikan sebagai item retur (`qty < 0`), melainkan langsung melakukan pembatalan transaksi penuh (VOID/CANCELLED) atau membuang nota sehingga persentase retur outlet tampak rendah dan produk terkesan berkualitas sempurna.

### Guard test-nya
Test `qty_negatif_bukan_refund` di `tests/test_definitions.yml`: memverifikasi apakah item berkuantitas negatif sinkron dengan status transaksi yang semestinya (REFUND).