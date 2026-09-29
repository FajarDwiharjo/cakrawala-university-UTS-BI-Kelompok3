# DESIGN_load — Strategi Load (UTS Item 2)

Dokumen ini menjelaskan strategi load dari source ke staging, dimension, dan fact. Setiap tabel memiliki strategi load, natural key, window jika diperlukan, serta aturan untuk mencegah duplicate saat proses load dijalankan kembali.

## Alur: sumber → staging → dim → fact

| # | Tabel                  | Sumber                                       | Strategi                                                               | Kapan menggandakan baris kalau dijalankan ulang                                                           |
| - | ---------------------- | -------------------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 1 | `dim_date`             | Generator tanggal                            | `CREATE OR REPLACE` (full load)                                        | Tidak menggandakan baris karena tabel dibangun ulang dari rentang tanggal.                                |
| 2 | `dim_product`          | `data/raw/t2_umkm/products.csv`              | Incremental SCD Type 2 berdasarkan `product_id` + `harga_berlaku_dari` | Jika versi dengan kombinasi key yang sama di-insert kembali tanpa pengecekan.                             |
| 3 | `dim_outlet`           | `data/raw/t2_umkm/outlets.csv`               | Upsert / SCD Type 1 berdasarkan `outlet_id`                            | Jika menggunakan `INSERT` biasa tanpa pengecekan `outlet_id`.                                             |
| 4 | `dim_status_transaksi` | `data/raw/t2_umkm/transactions.csv`          | Full load dengan `UPPER(status)` dan `DISTINCT`                        | Jika source dimuat kembali tanpa rebuild atau deduplication.                                              |
| 5 | `fact_transaksi_item`  | `transaction_items.csv` + `transactions.csv` | Incremental upsert dengan deduplication di staging                     | Jika menggunakan append tanpa pengecekan `item_id`, atau duplicate source tidak dibersihkan sebelum load. |

Staging digunakan untuk preprocessing sebelum data dimuat ke dimension dan fact. Pada fact, duplicate `item_id` dari `transaction_items` dibersihkan di staging. Duplicate header `transactions` yang identik juga dideduplicate. Transaction yang memiliki header berbeda tidak dipilih secara arbitrer sampai terdapat aturan untuk menentukan header yang valid.

## 1. Natural key

Natural key yang digunakan untuk upsert atau incremental load:

* `dim_product`: `product_id` + `harga_berlaku_dari`
* `dim_outlet`: `outlet_id`
* `dim_status_transaksi`: `status_code`
* `fact_transaksi_item`: `item_id`

Pada `dim_product`, `product_id` merupakan business key produk. Kombinasi `product_id` dan `harga_berlaku_dari` digunakan untuk membedakan versi produk pada SCD Type 2.

Pada `dim_status_transaksi`, `status_code` dibentuk dari nilai `status` yang sudah dinormalisasi menggunakan `UPPER(status)`.

Pada `fact_transaksi_item`, `item_id` digunakan sebagai natural key setelah duplicate item dari source dibersihkan di staging.

## 2. Kolom partisi atau window

Kolom yang digunakan sebagai window jika load dilakukan secara incremental:

* `dim_product`: `harga_berlaku_dari`
* `dim_outlet`: tidak ada
* `dim_status_transaksi`: tidak ada
* `fact_transaksi_item`: `transactions.tanggal_waktu`

`transaction_items.csv` tidak memiliki kolom tanggal, sehingga window untuk fact menggunakan `tanggal_waktu` dari `transactions`.

Sebelum digunakan sebagai window, data `transactions` perlu dideduplicate dan timestamp perlu dinormalisasi karena source memiliki lebih dari satu format timestamp, termasuk timestamp dengan akhiran `Z`.

## 3. Kapan strategi ini menggandakan baris kalau dijalankan dua kali?

### `dim_date`

Tidak menggandakan baris karena menggunakan `CREATE OR REPLACE`. Setiap proses load membangun ulang tabel berdasarkan rentang tanggal yang ditentukan.

### `dim_product`

Duplicate dapat terjadi jika kombinasi `product_id` dan `harga_berlaku_dari` yang sudah ada dimasukkan kembali tanpa pengecekan.

Untuk mencegahnya, proses load harus memeriksa kombinasi natural key sebelum insert. Jika terdapat versi produk baru, versi sebelumnya ditutup dan versi baru ditandai sebagai current.

### `dim_outlet`

Duplicate dapat terjadi jika data dimuat menggunakan `INSERT` tanpa pengecekan `outlet_id`.

Dengan upsert berdasarkan `outlet_id`, record outlet yang sudah ada akan diperbarui dan tidak dibuat sebagai baris baru.

### `dim_status_transaksi`

Duplicate dapat terjadi jika source di-append kembali tanpa rebuild atau deduplication.

Karena menggunakan full load dengan `UPPER(status)` dan `DISTINCT`, nilai status yang sama tidak akan terakumulasi saat proses dijalankan kembali.

### `fact_transaksi_item`

Duplicate dapat terjadi jika fact menggunakan append tanpa pengecekan `item_id`, atau jika duplicate `item_id` dari source tidak dibersihkan sebelum proses join.

Duplicate pada `transaction_items` harus dideduplicate di staging. Header `transactions` yang identik juga harus dideduplicate sebelum join. Hal ini diperlukan agar satu `item_id` hanya menghasilkan satu fact row.

Transaction yang memiliki header berbeda tidak digunakan untuk membentuk fact sampai terdapat aturan yang menentukan header yang valid. Dengan demikian, proses join tidak menghasilkan beberapa fact row untuk satu `item_id`.

## Urutan dependency

Urutan eksekusi yang direncanakan:

1. `dim_date`
2. `dim_product`
3. `dim_outlet`
4. `dim_status_transaksi`
5. `fact_transaksi_item`

`fact_transaksi_item` dimuat setelah dimension yang digunakan tersedia karena fact membutuhkan surrogate key dari dimension.

Sebelum fact dibentuk, data `transactions` dan `transaction_items` diproses di staging untuk deduplication dan penanganan data yang memiliki konflik.
