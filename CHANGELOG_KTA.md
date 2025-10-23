# Changelog - Sistem Nomor KTA

## Perubahan Tanggal 24 Oktober 2025

### 1. Format Nomor KTA
- **Sebelumnya**: `AABBCCYYYYYYYYYY` (16 digit tanpa separator)
- **Sekarang**: `AABBCC.YYYYYY` (format: 6 digit prefix + titik + 6 digit increment)

### 2. Logika Prefix KTA (AABBCC)
- **AA** = 2 digit terakhir kode provinsi **domisili saat daftar**
- **BB** = 2 digit terakhir kode kota/kabupaten **domisili saat daftar**
- **CC** = 2 digit terakhir kode kecamatan **domisili saat daftar**

### 3. Increment Nomor KTA (YYYYYY)
- Increment mulai dari `000001` sampai `999999`
- Increment berdasarkan kombinasi prefix `AABBCC`
- Setiap wilayah (kombinasi provinsi-kota-kecamatan) memiliki counter sendiri

### 4. Alamat Domisili
- Jika user **mencentang** "Domisili berbeda dengan KTP":
  - Sistem akan menggunakan provinsi/kota/kecamatan yang **dipilih user** di form
  - Nomor KTA dibuat berdasarkan alamat domisili yang dipilih
  
- Jika user **TIDAK mencentang** (domisili sama dengan KTP):
  - Sistem otomatis menggunakan alamat dari **NIK KTP**
  - Nomor KTA dibuat berdasarkan alamat di KTP

### 5. Validasi NIK Unik
- Setiap NIK hanya bisa mendaftar **satu kali**
- Validasi menggunakan `nik_fingerprint` (SHA256 hash)
- Error message: "NIK sudah terdaftar. Satu NIK hanya bisa mendaftar satu kali."

### 6. Contoh Kasus

#### Contoh 1: Domisili Sama dengan KTP
```
NIK: 3201012001010001 (Bogor, Jawa Barat)
Domisili: Sama dengan KTP (tidak dicentang)
Prefix KTA: 320101 (dari NIK)
Nomor KTA: 320101.000001
```

#### Contoh 2: Domisili Berbeda dari KTP
```
NIK: 3201012001010002 (Bogor, Jawa Barat)
Domisili: Jakarta Pusat, Gambir (diinput manual)
Prefix KTA: 317101 (dari domisili Jakarta)
Nomor KTA: 317101.000001
```

#### Contoh 3: Increment Nomor
```
Member 1 daftar di Bogor (320101) → KTA: 320101.000001
Member 2 daftar di Bogor (320101) → KTA: 320101.000002
Member 3 daftar di Jakarta (317101) → KTA: 317101.000001
Member 4 daftar di Bogor (320101) → KTA: 320101.000003
```

### 7. File yang Diubah

#### `app/models/member.rb`
- Tambah validasi `nik_fingerprint` unik
- Tambah validasi custom `domicile_or_ktp_address_present`
- Update method `assign_kta_number` dengan logika baru:
  - Gunakan alamat domisili jika ada
  - Format KTA: `AABBCC.YYYYYY`
  - Prefix dari kode wilayah domisili

#### `app/controllers/registrations_controller.rb`
- Update logic `create` untuk handle domisili:
  - Jika checkbox dicentang: simpan dom_area* dari input user
  - Jika tidak dicentang: copy area* dari NIK ke dom_area*
- Update pesan success dengan tampilkan nomor KTA

### 8. Basis Data

#### Tabel `members`
- `area2_code`, `area4_code`, `area6_code`: Alamat dari KTP (otomatis dari NIK)
- `dom_area2_code`, `dom_area4_code`, `dom_area6_code`: Alamat domisili saat daftar
- `kta_number`: Format baru `AABBCC.YYYYYY` (unique)
- `nik_fingerprint`: SHA256 hash NIK (unique)

#### Tabel `kta_sequences`
- `area6_code` (PK): Menyimpan prefix 6 digit (AABBCC)
- `last_value`: Counter terakhir untuk prefix tersebut
- Setiap prefix wilayah punya counter sendiri

### 9. Testing

Test dilakukan dengan skenario:
- ✅ Member dengan domisili = KTP
- ✅ Member dengan domisili ≠ KTP
- ✅ Increment nomor KTA pada wilayah yang sama
- ✅ Validasi duplikasi NIK
- ✅ Format nomor KTA sesuai spesifikasi

Semua test berhasil dijalankan tanpa error.
