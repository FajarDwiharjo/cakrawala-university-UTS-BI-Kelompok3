# DESIGN_load — strategi load (UTS item 2)

## 1. Strategi load

| # | Tabel                  | Sumber                                       | Strategi                                                                                                         | Jika dijalankan dua kali                           |
| - | ---------------------- | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| 1 | `dim_date`             | generator tanggal                            | `CREATE OR REPLACE` (full rebuild)                                                                               | Tidak menggandakan baris karena tabel dibuat ulang |
| 2 | `dim_product`          | `data/raw/t2_umkm/products.csv`              | `CREATE OR REPLACE` (full rebuild), dengan struktur SCD Type 2 berdasarkan `product_id` dan `harga_berlaku_dari` | Tidak menggandakan baris karena tabel dibuat ulang |
| 3 | `dim_outlet`           | `data/raw/t2_umkm/outlets.csv`               | `CREATE OR REPLACE` (full rebuild), dengan semantik SCD Type 1                                                   | Tidak menggandakan baris karena tabel dibuat ulang |
| 4 | `dim_status_transaksi` | domain status transaksi                      | `CREATE OR REPLACE` (full rebuild)                                                                               | Tidak menggandakan baris karena tabel dibuat ulang |
| 5 | `fact_transaksi_item`  | `transaction_items.csv` + `transactions.csv` | `CREATE OR REPLACE` (full rebuild), dengan grain satu item transaksi                                             | Tidak menggandakan baris karena tabel dibuat ulang |

## 2. Natural key

Natural key yang digunakan:

* `dim_product`: `product_id` + `harga_berlaku_dari`
* `dim_outlet`: `outlet_id`
* `dim_status_transaksi`: `status_code`
* `fact_transaksi_item`: `(transaction_id, item_id)`

Untuk `dim_date`, `date_sk` dibentuk dari tanggal dan digunakan sebagai surrogate key.

## 3. Kolom partisi / window

Load menggunakan full rebuild, sehingga tidak ada proses incremental dan tidak membutuhkan kolom partisi atau window untuk load.

Pada `dim_product`, `harga_berlaku_dari` digunakan untuk menentukan periode harga. `valid_to` ditentukan dari tanggal mulai harga berikutnya.

Pada `fact_transaksi_item`, tanggal transaksi digunakan untuk mendapatkan `date_sk` dari `dim_date`.

## 4. Idempotensi dan risiko duplikasi

Semua tabel menggunakan `CREATE OR REPLACE`, sehingga menjalankan load dua kali tidak menambahkan data dari proses sebelumnya.

Duplikasi masih bisa terjadi saat membentuk `fact_transaksi_item` jika terdapat duplicate key pada source yang menyebabkan hasil `JOIN` menjadi lebih dari satu baris untuk satu item.

Untuk menjaga grain fact, satu `item_id` dalam satu transaksi harus menghasilkan satu baris fact. Duplicate `transaction_id` pada `transactions.csv` juga perlu ditangani sebelum proses `JOIN` agar tidak menyebabkan baris fact menjadi berlipat.

## 5. Urutan dependency

Urutan load:

1. `dim_date`
2. `dim_product`
3. `dim_outlet`
4. `dim_status_transaksi`
5. `fact_transaksi_item`

`fact_transaksi_item` dimuat terakhir karena menggunakan key dari seluruh dimensi tersebut.
