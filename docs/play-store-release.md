# Persiapan Google Play Closed Testing

## Build saat ini

- Application ID: `id.my.duniapinta.gembalakecil`
- Versi: `1.0.0 (2)`
- Tipe rilis: Android App Bundle (`.aab`)
- Signing: upload key khusus Gembala Kecil
- Privacy policy: <https://api-gembalakecil.duniapinta.my.id/privacy>
- Penghapusan akun: <https://api-gembalakecil.duniapinta.my.id/account-deletion>

Jangan kehilangan `android/upload-keystore.jks` dan `android/key.properties`. Simpan keduanya di password manager atau penyimpanan terenkripsi. File tersebut sengaja tidak masuk GitHub.

## Yang harus dilakukan pemilik akun Play Console

1. Buat aplikasi baru bernama **Gembala Kecil** dan pilih bahasa utama Indonesia.
2. Aktifkan Play App Signing saat upload AAB pertama.
3. Ambil SHA-1 **App signing key certificate** dari **Setup → App integrity**, lalu tambahkan ke Android app di Firebase. SHA ini berbeda dari upload key.
4. Lengkapi Store listing, App access, Ads, Content rating, Target audience and content, Data safety, serta privacy policy URL.
5. Buat closed testing track, upload AAB, tambahkan daftar tester, lalu kirim rilis untuk review.
6. Bila akun developer personal dibuat setelah 13 November 2023, penuhi syarat tester aktif yang ditampilkan Play Console sebelum meminta akses Production.

## Jawaban deklarasi awal

- Ads: **No**.
- Target audience: pilih rentang usia anak yang benar-benar dituju (rancangan produk saat ini cocok untuk anak sekitar 3–8 tahun) dan deklarasikan bahwa aplikasi ditujukan untuk anak.
- App access: konten gratis dapat diakses tanpa login. Sertakan bahwa akun orang tua opsional.
- Data safety: aplikasi memproses email/ID akun orang tua, nama panggilan/profil anak, progres membaca, dan status pembelian bila akun digunakan. Autentikasi memakai Firebase/Google, konten memakai Cloudflare, distribusi/pembelian memakai Google Play.
- Account deletion URL: gunakan URL penghapusan akun di atas.

Jawaban Data safety harus diperiksa ulang terhadap SDK dan perilaku build final di Play Console; jangan sekadar menyalin tanpa membaca pertanyaannya.

## Premium yang belum boleh diaktifkan

Rencana produk: pembelian satu kali `Rp49.000` untuk membuka semua cerita kini dan mendatang. Harga lama `Rp99.000` hanya elemen promosi UI.

Sebelum tombol beli diaktifkan:

1. Buat one-time product/non-consumable di Play Console dan tentukan product ID permanen.
2. Aktifkan Google Play Developer API dan berikan backend akses untuk memverifikasi purchase token.
3. Implementasikan endpoint server untuk verifikasi, acknowledgement, refund/revocation, dan penulisan entitlement ke Firestore.
4. Hubungkan Play Billing di aplikasi, termasuk restore purchases dan penanganan pending purchase.
5. Tes menggunakan license tester serta internal/closed track.

Jangan menyimpan service-account key atau secret Google Play di aplikasi maupun GitHub. Sampai backend verifikasi selesai, tombol premium harus tetap nonaktif agar tester tidak dapat membayar tanpa menerima entitlement.

## Checklist pengujian closed track

- Instal dari link Play testing, bukan sideload, untuk menguji billing dan Play signing.
- Uji perangkat layar kecil dan besar, Android versi minimum, koneksi lambat, offline, unduhan terputus, dan ruang penyimpanan hampir penuh.
- Uji akun email/password: verifikasi email, login, reset password, logout, dan sinkronisasi.
- Uji Google Sign-In setelah SHA app-signing Play ditambahkan ke Firebase.
- Uji cerita gratis pertama dan kesepuluh, Ayat Hafalan gratis, cerita terkunci, download progress, pembatalan download, serta pembukaan ulang offline.
- Pastikan semua cover muncul sebelum modul penuh diunduh dan tidak ada halaman kosong.
- Buka privacy policy dan formulir penghapusan akun dari aplikasi.
- Kirim satu permintaan penghapusan uji, proses sampai Firebase Auth/Firestore terhapus, lalu hapus juga berkas permintaannya dari R2.

## Copy Store listing

**Nama aplikasi**  
Gembala Kecil

**Deskripsi singkat**  
Cerita Alkitab interaktif, audio, dan ayat hafalan untuk anak.

**Deskripsi lengkap**  
Temani anak mengenal kisah-kisah Alkitab bersama Gembala Kecil. Setiap cerita hadir dengan ilustrasi ramah anak, teks yang mudah dibaca, serta narasi dengan sorotan kata agar anak dapat mengikuti ceritanya.

Anak dapat membaca sendiri atau mendengarkan cerita, mengunduh modul untuk dinikmati kembali, dan belajar Ayat Hafalan. Sepuluh cerita serta seluruh Ayat Hafalan tersedia gratis. Akun orang tua bersifat opsional untuk menyimpan profil anak, progres, dan pembelian di perangkat lain.

Fitur utama:

- Cerita Alkitab berilustrasi dan ramah anak
- Narasi audio dengan sorotan kata
- Mode otomatis untuk mendengarkan berkelanjutan
- Unduh cerita untuk dibaca kembali
- Ayat Hafalan gratis
- Profil anak dan sinkronisasi melalui akun orang tua opsional
- Tanpa iklan

**Catatan rilis closed testing**  
Versi pengujian awal Gembala Kecil: cerita interaktif, unduhan modul, narasi dengan sorotan kata, Ayat Hafalan, akun orang tua opsional, dan sinkronisasi progres.
