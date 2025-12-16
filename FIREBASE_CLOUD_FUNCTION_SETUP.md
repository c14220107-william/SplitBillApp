# Setup Firebase Cloud Function untuk Push Notification

## Prerequisites
- Node.js installed
- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase project already created (splitbill-app-83f1f)

## Step 1: Initialize Firebase Functions

```bash
# Login to Firebase
firebase login

# Initialize Firebase in project (dari root folder splitbillapp)
firebase init functions

# Pilih:
# - Select project: splitbill-app-83f1f
# - Language: JavaScript
# - ESLint: No (optional)
# - Install dependencies: Yes
```

## Step 2: Setup Cloud Function

Setelah init, akan ada folder `functions/`. Edit file `functions/index.js`:

```javascript
const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Initialize Firebase Admin SDK
admin.initializeApp();

// HTTP Cloud Function to send FCM push notification
exports.sendPushNotification = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { tokens, title, body, data } = req.body;

    if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
      res.status(400).json({ error: 'tokens array is required' });
      return;
    }

    // Prepare FCM message
    const message = {
      notification: {
        title: title || 'Notification',
        body: body || '',
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    // Send to multiple tokens
    const promises = tokens.map(token => {
      return admin.messaging().send({
        ...message,
        token: token,
      });
    });

    const results = await Promise.allSettled(promises);
    
    const successCount = results.filter(r => r.status === 'fulfilled').length;
    const failureCount = results.filter(r => r.status === 'rejected').length;

    console.log(\`Push notification sent: \${successCount} success, \${failureCount} failed\`);

    res.status(200).json({
      success: true,
      successCount,
      failureCount,
      results: results.map((r, i) => ({
        token: tokens[i].substring(0, 20) + '...',
        status: r.status,
        error: r.status === 'rejected' ? r.reason.message : null,
      })),
    });

  } catch (error) {
    console.error('Error sending push notification:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});
```

## Step 3: Deploy Cloud Function

```bash
# Dari root folder project
cd functions

# Deploy function ke Firebase
firebase deploy --only functions

# Output akan menampilkan URL:
# ✔  functions[sendPushNotification(us-central1)]: Successful create operation.
# Function URL: https://us-central1-splitbill-app-83f1f.cloudfunctions.net/sendPushNotification
```

## Step 4: Update Flutter App

Copy **Function URL** dari output deploy, lalu update:

`lib/features/notifications/services/notification_service.dart` line 12:

```dart
static const String? _cloudFunctionUrl = 
  'https://us-central1-splitbill-app-83f1f.cloudfunctions.net/sendPushNotification';
```

## Step 5: Test

```bash
# Hot reload app
r

# Test flow:
# 1. Login sebagai host
# 2. Create & finalize bill
# 3. Invited user HARUSNYA dapat push notification (bahkan app tertutup!)
```

## Troubleshooting

### Error: "Failed to send push"
- Cek Firebase Console > Functions > Logs
- Pastikan FCM tokens valid di Supabase

### Error: "CORS"
- CORS headers sudah di-handle di Cloud Function
- Kalau masih error, coba deploy ulang

### Error: "Billing account required"
- Firebase Functions butuh Blaze Plan (pay-as-you-go)
- Tapi ada free tier 2 juta invocations/bulan
- Cukup untuk development

## Cost

Firebase Functions **Blaze Plan** (FREE TIER):
- 2 juta invocations/bulan (free)
- 400,000 GB-seconds/bulan (free)
- 200,000 CPU-seconds/bulan (free)

Untuk app split bill, **GRATIS** karena notification tidak banyak!

## Alternative: Tanpa Cloud Function

Kalau tidak mau setup Cloud Function, gunakan **in-app notification** saja:
- Notification tetap masuk ke database
- User dapat notif saat buka app
- Badge notification tetap muncul
- Cukup untuk MVP/testing

Tapi untuk **production**, sebaiknya pakai Cloud Function agar:
- User dapat push notification real-time
- Bahkan saat app tertutup/background
- Better UX!
