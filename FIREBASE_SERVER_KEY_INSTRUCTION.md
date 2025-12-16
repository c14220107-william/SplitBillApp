# Firebase Server Key Setup

## Cara Dapatkan Firebase Server Key:

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Pilih project **splitbill-app-83f1f**
3. Klik **⚙️ (gear icon)** → **Project settings**
4. Tab **Cloud Messaging**
5. Scroll ke bawah cari **"Cloud Messaging API (Legacy)"**
6. Copy **Server key** (format: `AAAAxxx...`)

## Cara Pakai:

Setelah dapat Server Key, update file:
`lib/features/notifications/services/notification_service.dart`

Line 11:
```dart
static const _firebaseServerKey = 'PASTE_SERVER_KEY_DISINI';
```

**PENTING**: 
- Server key harus dalam quotes (string)
- Jangan commit ke Git (add ke .gitignore kalau project public)
- Format: `AAAA...` (starts with AAAA)

## Test:

Setelah update server key:
1. Hot reload app: `r` di terminal
2. Login sebagai host
3. Create & finalize bill
4. Invited user harusnya dapat push notification! 📱
