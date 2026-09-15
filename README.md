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

Audio cerita pertama kini memakai timestamp kata hasil audit lokal di `assets/story/timing.json`. Hasil audit dan dua titik yang perlu dengar manual ada di `audit/story_audio_report.md`. Pendaftaran/login akun orang tua, profil anak, reset password, dan sinkronisasi progress sudah tersambung ke Firebase. Pembelian store belum diaktifkan; entitlement hanya dapat ditulis oleh backend tepercaya.

Backoffice upload cerita dan Ayat Hafalan tersedia di `http://127.0.0.1:57183/` ketika `node backoffice/server.js` dijalankan. Lihat `backoffice/README.md` untuk format konten dan timing.

Asset story yang dipakai berada di `assets/story/`, sedangkan logo dan mascot berada di `assets/brand/`.

Fondasi backend tersedia di `firebase.json`, `firestore.rules`, dan `cloudflare/content-worker/`. Firebase project `gembala-kecil` sudah terhubung untuk Web, Android, dan iOS; Firestore rules sudah aktif. Cloudflare Worker/R2 tersedia di `https://api-gembalakecil.duniapinta.my.id`. Aplikasi memuat katalog cloud dengan fallback bundle lokal, sedangkan backoffice memiliki tombol publish R2. Purchase verification masih menjadi tahap berikutnya. Lihat `docs/backend-setup.md` untuk arsitektur lengkap.
