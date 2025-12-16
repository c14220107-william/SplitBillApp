# Setup Push Notification dengan Supabase Webhook (Paling Simpel!)

## Cara Kerja:
1. User finalize bill → notif masuk database
2. Supabase Webhook trigger otomatis → kirim ke service kita
3. Service kirim FCM push → muncul di HP (bahkan saat app ditutup!)

## Opsi 1: Pakai Service Gratis (n8n.cloud atau Zapier)

### Menggunakan n8n.cloud (Recommended - Gratis)

1. **Daftar n8n.cloud**
   - Buka: https://n8n.cloud/
   - Sign up gratis (tidak perlu kartu kredit)

2. **Buat Workflow**
   - New Workflow → Add node → Webhook
   - Copy webhook URL (contoh: `https://yourname.app.n8n.cloud/webhook/xxxxx`)

3. **Add FCM Node**
   - Add node → HTTP Request
   - Method: POST
   - URL: `https://fcm.googleapis.com/v1/projects/splitbill-app-83f1f/messages:send`
   - Authentication: OAuth2
   - (atau pakai service account - lebih mudah dengan HTTP node + Bearer token)

4. **Setup di Supabase**
   - Dashboard → Database → Webhooks
   - Create webhook:
     - Table: `notifications`
     - Event: `INSERT`
     - Type: `HTTP Request`
     - Method: `POST`
     - URL: webhook URL dari n8n
     - HTTP Headers: `Content-Type: application/json`

## Opsi 2: Pakai Make.com (Integromat) - Paling Mudah!

1. **Daftar Make.com**
   - Buka: https://www.make.com/
   - Free plan: 1000 operations/month (cukup untuk testing)

2. **Buat Scenario**
   - New Scenario
   - Add module → Webhooks → Custom Webhook
   - Copy webhook URL

3. **Add FCM Module**
   - Search "Firebase" atau gunakan HTTP module
   - Setup FCM dengan Server Key (Legacy) atau Service Account

4. **Setup di Supabase**
   - Sama seperti opsi 1

## Opsi 3: Pakai Supabase Edge Function (Butuh Deploy)

Sudah dijelaskan sebelumnya, tapi butuh deploy dan setup service account.

## Opsi 4: Deploy Backend Sendiri (Paling Kompleks)

Buat simple backend di:
- Vercel/Netlify (serverless function)
- Railway/Render (Node.js server)
- Google Cloud Run

---

## Rekomendasi untuk Kamu:

**Pakai Make.com** karena:
- ✅ UI paling mudah (drag & drop)
- ✅ Ada module FCM built-in
- ✅ Free 1000 ops/month
- ✅ Tidak perlu coding
- ✅ Setup < 10 menit

**Atau tetap pakai solusi sekarang (Realtime) untuk MVP:**
- Push notification muncul saat app **dibuka**
- Badge notification tetap jalan
- Simpel, tidak perlu service tambahan
- Cukup untuk demo/testing

Mau pakai yang mana? Atau mau saya buatkan backend simpel?
