# D6 — Kamus metrik (12 field)

> UTS item 5 menilai **satu** metrik lengkap; UAS menilai tiga. Setiap metrik wajib punya berkas SQL
> di `sql/50_metrics/` — definisi yang tidak bisa dijalankan belum tentu benar.

## Metrik 1 — Omzet Bersih Bulanan per Outlet

| # | Field | Isi |
|---|---|---|
| 1 | Nama metrik | Omzet Bersih Bulanan per Outlet |
| 2 | Definisi (satu kalimat, tanpa jargon) | Total nilai penjualan item (qty × harga − diskon) dari transaksi berstatus PAID dalam satu bulan kalender di satu outlet, setelah nilai retur (qty negatif) sudah mengurangi total. |
| 3 | Rumus (SQL-nya, bukan bahasa manusia) | `SUM(f.subtotal_rupiah)` pada `fact_transaksi_item f` di-filter `s.status_code = 'PAID'`, GROUP BY `o.outlet_id, d.tahun, d.bulan` |
| 4 | Grain | Satu outlet × satu bulan kalender (contoh: OUT-A, 2025, 3) |
| 5 | Tabel sumber | `fact_transaksi_item` JOIN `dim_date` (date_sk), `dim_outlet` (outlet_sk), `dim_status_transaksi` (status_sk) |
| 6 | Owner (jabatan bernama) | Manajer Operasional Outlet (penanggung jawab target omzet bulanan tiap outlet) |
| 7 | Time basis | per bulan kalender WIB (Januari–Desember, bukan rolling 30 hari) |
| 8 | Satuan | Rupiah (IDR), bilangan bulat, tanpa desimal |
| 9 | Dimensi yang boleh dipotong | outlet_id, tahun, bulan, triwulan, kategori produk (via dim_product.kategori) |
| 10 | Filter default | `status_code = 'PAID'`, `outlet_id IN ('OUT-A','OUT-B','OUT-C')`, `tahun = 2025` |
| 11 | Arti nilai kosong | Tidak ada transaksi PAID di bulan tersebut untuk outlet itu — tampilkan Rp0, bukan NULL |
| 12 | Versi | v1, berlaku 2026-09-01 |

### Cara metrik ini di-gaming
Outlet dapat meningkatkan omzet dengan membuat transaksi void lalu merekam ulang sebagai PAID (split transaction) — transaksi yang sama dicatat dua kali dengan status berbeda sehingga subtotal_rupiah terhitung dobel, padahal uang yang masuk sama.

### Guard test-nya
```sql
-- Deteksi: transaction_id yang muncul lebih dari sekali di fact dengan status PAID
-- Jika hasilnya > 0, ada potensi double-counting
SELECT count(*)
FROM (
    SELECT f.transaction_id
    FROM fact_transaksi_item f
    JOIN dim_status_transaksi s ON s.status_sk = f.status_sk
    WHERE s.status_code = 'PAID'
    GROUP BY f.transaction_id
    HAVING count(DISTINCT f.item_id) <> count(f.item_id)  -- ada item_id duplikat per transaksi
)
```
