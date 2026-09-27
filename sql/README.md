# sql/ — DDL Desain Star Schema
## Kelompok 3 | T2 POS UMKM — Outlet A+B+C, 12 bulan (slice k8)

## Urutan eksekusi

| Urutan | File | Isi |
|--------|------|-----|
| 1 | `10_dim_date.sql` | Dimensi tanggal (konformed, diberikan lengkap) |
| 2 | `20_dim_product.sql` | Dimensi produk — **SCD Type 2** (histori harga) |
| 3 | `20_dim_outlet.sql` | Dimensi outlet — SCD Type 1 (master referensi) |
| 4 | `20_dim_status_transaksi.sql` | Dimensi status — SCD Type 0 (kamus statis) |
| 5 | `30_fact_transaksi_item.sql` | Fact table utama — grain per item transaksi |
| 6 | `40_analytics/` | Kueri analitik q01–q03 |

## Grain

> **Satu baris = satu item produk yang terjual dalam satu transaksi di satu outlet pada satu tanggal.**

## Star Schema

```
                    dim_date
                   (date_sk)
                       │
dim_outlet ────── fact_transaksi_item ────── dim_product
(outlet_sk)      (date_sk FK)               (product_sk FK)
                 (product_sk FK)
                 (outlet_sk FK)
                 (status_sk FK)
                       │
               dim_status_transaksi
                   (status_sk)
```

## SCD Summary

| Dimensi | SCD Type | Alasan |
|---------|----------|--------|
| `dim_date` | Tipe 0 | Tanggal tidak pernah berubah |
| `dim_product` | **Tipe 2** | Harga satuan berubah; butuh histori untuk rekonsiliasi nilai transaksi historis |
| `dim_outlet` | Tipe 1 | Perubahan identitas outlet merupakan koreksi data, bukan event bisnis |
| `dim_status_transaksi` | Tipe 0 | Kamus domain sistem POS — statis |

## Catatan profiling (slice k8)

- `transactions.csv`: 15.892 baris, 15.671 id unik → **219 duplikat**
- `transaction_items.csv`: 31.343 baris, **628 qty negatif** (retur)
- `transaction_items.csv`: **1 FK orphan** (product_id tidak ada di products.csv)
- `products.csv`: 120 produk, 9 varian harga satuan
- `transactions.csv`: **5 varian status** (PAID, PENDING, CANCELLED, REFUNDED, PARTIAL)
