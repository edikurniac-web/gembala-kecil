# Backoffice lokal

Jalankan `node backoffice/server.js`, lalu buka `http://127.0.0.1:57183/`.

Cerita baru memerlukan judul, referensi, cover PNG persegi, teks halaman yang dipisahkan baris `---`, dan jumlah ilustrasi PNG persegi yang sama. Bila ada narasi MP3, sertakan timing kata JSON agar highlight sinkron. Upload Ayat Hafalan memerlukan judul, referensi, dan teks ayat; ilustrasi serta audio opsional.

Format timing cerita:

```json
{
  "version": 1,
  "audioDurationMs": 12000,
  "pages": [
    { "startMs": 0, "endMs": 12000, "wordStartsMs": [300, 620, 950] }
  ]
}
```

Panjang `wordStartsMs` harus sama dengan jumlah kata yang dipisahkan spasi pada teks halaman. Contoh lengkap ada di `assets/story/timing.json`. Untuk cerita pertama, `tool/audit_story_audio.py` membuat transkripsi bertimestamp secara lokal, kemudian `tool/build_story_timing.py` menyelaraskannya ke teks.

Konten disimpan sebagai file datar di `assets/content/` dan dicatat di `catalog.json`. Setelah upload, jalankan `flutter build web --no-pub` untuk memasukkan asset baru ke preview Flutter di port 57182. Backoffice hanya menerima koneksi lokal dan tidak mengunggah file ke layanan luar.

## Edit dan hapus cerita

Klik **Edit cerita** pada daftar konten tersimpan. Judul, referensi, ringkasan, status gratis, teks, cover, narasi, dan ilustrasi per halaman dapat diubah. File yang tidak dipilih tetap memakai versi lama. Jumlah halaman tidak dapat berubah saat edit; untuk mengubah struktur halaman, unggah cerita baru. Jika narasi MP3 atau teks halaman berubah, unggah timing kata JSON baru supaya highlight tetap cocok. Ilustrasi dapat diganti tanpa mengubah timing.

Klik **Hapus cerita** untuk mengeluarkan cerita dari katalog. Backoffice meminta konfirmasi lebih dulu dan memindahkan asetnya ke `assets/content/.trash/`, bukan menghapus permanen. Perubahan edit maupun hapus baru terlihat di aplikasi setelah build ulang dan refresh preview. Cerita bawaan yang berada di `assets/story/` tidak dapat diedit atau dihapus lewat backoffice ini.
