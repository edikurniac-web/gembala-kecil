# Gembala Kecil

App Flutter untuk cerita Alkitab anak. Preview lokal di `http://127.0.0.1:57182/` menyajikan hasil build Flutter web dari `build/web`.

## Flow yang sudah dibuat

- Splash logo → onboarding nama panggilan.
- Nama anak disimpan lokal melalui `shared_preferences`.
- Account orang tua bersifat opsional dan bisa dilewati.
- Homepage fixed/non-scroll dengan featured story, Semua Cerita, dan Ayat Hafalan placeholder.
- Daftar cerita scrollable dengan cover, judul, referensi ayat, dan status sudah dibaca.
- Detail cerita dengan pilihan `Dibacakan Gembala` atau `Baca Sendiri`.
- Reader 12 halaman memakai ilustrasi persegi, audio MP3, highlight kata, dan toggle Otomatis.
- Parent account area dengan child profile, purchase entitlement, dan sync placeholder.
- Seluruh UI memakai Fredoka.

## Menjalankan

```bash
flutter pub get
flutter run
```

Untuk memperbarui preview web:

```bash
flutter build web --no-pub
node preview-server.js
```

Audio cerita pertama kini memakai timestamp kata hasil audit lokal di `assets/story/timing.json`. Hasil audit dan dua titik yang perlu dengar manual ada di `audit/story_audio_report.md`. Pendaftaran akun, pembelian, dan sinkronisasi belum tersambung ke backend; UI menjelaskan status ini saat tombol akun ditekan.

Backoffice upload cerita dan Ayat Hafalan tersedia di `http://127.0.0.1:57183/` ketika `node backoffice/server.js` dijalankan. Lihat `backoffice/README.md` untuk format konten dan timing.

Asset story yang dipakai berada di `assets/story/`, sedangkan logo dan mascot berada di `assets/brand/`.

Fondasi backend tersedia di `firebase.json`, `firestore.rules`, dan `cloudflare/content-worker/`. Pembagian layanan, model data akun/profil anak, aturan entitlement, dan urutan aktivasi dijelaskan di `docs/backend-setup.md`. Konfigurasi ini belum terhubung ke project cloud sampai pemilik login dan memasukkan project ID serta domain miliknya.
