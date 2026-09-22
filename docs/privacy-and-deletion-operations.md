# Operasional Privasi dan Penghapusan Akun

Halaman publik:

- Privacy policy: <https://api-gembalakecil.duniapinta.my.id/privacy>
- Penghapusan akun: <https://api-gembalakecil.duniapinta.my.id/account-deletion>
- Kontak privasi: <https://api-gembalakecil.duniapinta.my.id/contact>

Permintaan penghapusan disimpan sebagai JSON di bucket R2 `gembala-kecil-content`, prefix `private/deletion-requests/`. Prefix `private/` ditolak oleh endpoint aset publik.

Pesan kontak privasi disimpan pada prefix `private/contact-requests/` dan harus ditinjau berkala melalui Cloudflare Dashboard.

Untuk setiap permintaan:

1. Buka bucket R2 di Cloudflare Dashboard dan cari file pada prefix tersebut.
2. Verifikasi bahwa pemohon menguasai email akun. Jangan meminta password.
3. Di Firebase Authentication, cari email tersebut dan catat UID.
4. Hapus dokumen `parents/{uid}` beserta seluruh subcollection anak, progress, dan entitlement secara rekursif.
5. Hapus user tersebut dari Firebase Authentication.
6. Hapus file permintaan dari R2 setelah selesai dan simpan hanya catatan minimal yang wajib untuk audit/hukum.
7. Beri konfirmasi kepada pemohon melalui email.

Sebelum rilis publik yang besar, alur manual ini sebaiknya diganti backend terautentikasi yang menghapus Firebase Auth dan Firestore secara atomis, memiliki rate limiting, serta mencatat status tanpa mengekspos data pribadi.
