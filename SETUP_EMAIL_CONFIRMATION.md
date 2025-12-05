# ⚠️ LANGKAH PENTING: Setup Email Confirmation - Deep Link

## 🎯 Yang Harus Dilakukan SEKARANG

### ✅ Langkah 1: Konfigurasi di Supabase Dashboard (WAJIB!)

1. **Buka Supabase Dashboard**: https://supabase.com/dashboard/project/wpvncmajhozcfahgiscx
2. **Klik menu "Authentication"** di sidebar kiri
3. **Klik tab "URL Configuration"**
4. **Scroll ke bawah sampai ketemu bagian "Redirect URLs"**
5. **Tambahkan URL ini**:
   ```
   io.supabase.splitbillapp://login-callback
   ```
6. **Klik tombol "Add URL"** atau "Save"
7. **PENTING**: Tunggu beberapa detik sampai saved (ada notifikasi hijau)

### Screenshot Lokasi:
```
Dashboard → Authentication (sidebar) → URL Configuration (tab) → Redirect URLs (bagian bawah)
```

---

### ✅ Langkah 2: Rebuild Aplikasi

Jalankan command ini di terminal:

```powershell
flutter clean
flutter pub get
flutter run
```

**PENTING**: 
- JANGAN hot reload/restart
- HARUS run ulang sepenuhnya
- Tunggu sampai build selesai

---

### ✅ Langkah 3: Test Email Confirmation

1. **Registrasi user baru** (atau gunakan user yang belum verified)
2. **Cek email** di aplikasi Gmail Android
3. **Klik link "Confirm your email"**
4. **Harusnya aplikasi splitbillapp terbuka otomatis**
5. **User langsung login** dan redirect ke /home

---

## 🔍 Jika Masih Error "An error occurred"

### Cek 1: Apakah Redirect URL sudah benar?

Login ke Supabase → Authentication → URL Configuration

Pastikan ada:
```
io.supabase.splitbillapp://login-callback
```

**TANPA**:
- Spasi di awal/akhir
- Huruf besar (semua lowercase)
- Karakter tambahan

### Cek 2: Apakah sudah rebuild penuh?

```powershell
flutter clean
flutter pub get  
flutter run
```

**JANGAN:**
- Hot reload (R)
- Hot restart (Shift+R)  
- Run tanpa clean

### Cek 3: Test deep link manual

Di terminal, jalankan:
```powershell
adb shell am start -W -a android.intent.action.VIEW -d "io.supabase.splitbillapp://login-callback"
```

Jika aplikasi terbuka, berarti deep link sudah bekerja.

### Cek 4: Lihat log console

Saat klik link email, lihat log di VS Code terminal:

**Yang seharusnya muncul:**
```
🔐 Auth event: signedIn
✅ User signed in via deep link
```

**Jika muncul error:**
- Copy error message lengkap
- Screenshot error di email
- Share ke chat

---

## 📱 Cara Kerja (Teknis)

### Flow Normal:
1. User register → Supabase kirim email
2. User klik link di email → Format: `https://wpvncmajhozcfahgiscx.supabase.co/auth/v1/verify?token=xxx&redirect_to=io.supabase.splitbillapp://login-callback`
3. Supabase verify token → Jika valid, redirect ke deep link
4. Android detect scheme `io.supabase.splitbillapp://` → Buka app
5. Supabase Flutter SDK handle callback → User auto login
6. Router redirect ke `/home`

### Yang Sudah Disetup:

✅ **AndroidManifest.xml**: Deep link intent filter  
✅ **supabase_config.dart**: Auth flow PKCE  
✅ **main.dart**: Auth state listener  
✅ **app_router.dart**: Auth redirect logic  
✅ **login_page.dart**: Error handling untuk unconfirmed email

### Yang Masih Kurang:

❌ **Redirect URL di Supabase Dashboard** ← **INI YANG PALING PENTING!**

---

## ⚠️ Catatan Penting

1. **Deep link hanya bekerja di:**
   - Physical Android device
   - Emulator dengan Google Play Services

2. **Perlu rebuild penuh** setelah:
   - Ubah AndroidManifest.xml
   - Ubah Redirect URLs di Supabase
   - Flutter clean

3. **Redirect URL HARUS SAMA** di:
   - Supabase Dashboard → Authentication → URL Configuration
   - AndroidManifest.xml → intent-filter data scheme+host

4. **Format URL:**
   - ✅ BENAR: `io.supabase.splitbillapp://login-callback`
   - ❌ SALAH: `io.supabase.splitbillapp//login-callback` (double slash)
   - ❌ SALAH: `io.supabase.splitbillapp:login-callback` (kurang //)
   - ❌ SALAH: `io.supabase.splitbillapp://` (kurang host)

---

## 🚨 Error Messages dan Solusinya

### "An error occurred" di browser saat klik link email
**Penyebab**: Redirect URL belum dikonfigurasi di Supabase  
**Solusi**: Tambahkan `io.supabase.splitbillapp://login-callback` di Supabase Dashboard

### Link membuka browser tapi tidak membuka app
**Penyebab**: AndroidManifest atau rebuild belum benar  
**Solusi**: `flutter clean`, `flutter pub get`, `flutter run`

### "Email not confirmed" terus muncul meskipun sudah klik link
**Penyebab**: Deep link tidak handled, user tidak benar-benar ter-verify  
**Solusi**: Setup Redirect URL di Supabase + rebuild app

### Gmail app tidak terbuka
**Penyebab**: Sudah solved, sekarang sudah bisa  
**Log**: `✅ Gmail app opened via android-app`

---

## 📞 Need Help?

Jika masih error setelah:
1. ✅ Tambah Redirect URL di Supabase
2. ✅ Flutter clean + rebuild
3. ✅ Test dengan user baru

Share:
- Screenshot error di browser/app
- Log console lengkap (copy semua text)
- Screenshot Supabase → Authentication → URL Configuration
