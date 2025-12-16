# Firebase Push Notification Setup Guide

## Prerequisites
Aplikasi Flutter Anda sudah ter-install packages:
- `firebase_core`
- `firebase_messaging`
- `flutter_local_notifications`

## Step 1: Create Firebase Project

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Klik **"Add project"** atau **"Create a project"**
3. Masukkan nama project: **splitbillapp**
4. (Optional) Enable Google Analytics
5. Klik **"Create project"**

## Step 2: Add Android App to Firebase

1. Di Firebase Console, pilih project **splitbillapp**
2. Klik icon **Android** untuk menambahkan Android app
3. Isi form:
   - **Android package name**: `com.example.splitbillapp`
   - **App nickname** (optional): `Splitbillers`
   - **Debug signing certificate SHA-1** (optional untuk sekarang)
4. Klik **"Register app"**

## Step 3: Download google-services.json

1. Download file `google-services.json`
2. **Copy file ini ke folder**: `android/app/`
   ```
   splitbillapp/
   └── android/
       └── app/
           └── google-services.json  <-- PASTE DI SINI
   ```

## Step 4: Configure Android Project

### 4.1 Update `android/build.gradle.kts`

Tambahkan Google Services plugin di bagian `plugins`:

```kotlin
plugins {
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false  // ADD THIS
}
```

### 4.2 Update `android/app/build.gradle.kts`

Tambahkan di bagian **paling atas** setelah `plugins`:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ADD THIS
}
```

### 4.3 Update `android/app/src/main/AndroidManifest.xml`

Tambahkan permission dan service untuk notifications:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

    <application
        android:label="splitbillapp"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Existing MainActivity -->
        <activity
            android:name=".MainActivity"
            ...>
        </activity>

        <!-- Add Firebase Messaging Service -->
        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <!-- Default notification channel (untuk Android 8.0+) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />
    </application>
</manifest>
```

## Step 5: Create Supabase Database Table

Jalankan SQL ini di **Supabase SQL Editor**:

```sql
-- File: create_user_devices_table.sql
-- (Sudah ada di root project)
```

Copy isi dari `create_user_devices_table.sql` dan execute di Supabase.

## Step 6: Create Supabase Edge Function (Server-side)

Untuk mengirim push notification dari server saat bill finalized, kita perlu **Supabase Edge Function** yang akan dipanggil dari `NotificationService.sendBillFinalizedNotification()`.

### 6.1 Install Supabase CLI

```bash
npm install -g supabase
```

### 6.2 Create Edge Function

Di terminal, dari root project:

```bash
# Login to Supabase
supabase login

# Link project
supabase link --project-ref YOUR_PROJECT_REF

# Create edge function
supabase functions new send-push-notification
```

### 6.3 Update Edge Function Code

Edit file `supabase/functions/send-push-notification/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const FIREBASE_SERVER_KEY = Deno.env.get('FIREBASE_SERVER_KEY')!

serve(async (req) => {
  try {
    const { fcmTokens, title, body, data } = await req.json()

    // Send to multiple devices
    const promises = fcmTokens.map((token: string) => 
      fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${FIREBASE_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token,
          notification: {
            title,
            body,
          },
          data,
          priority: 'high',
        }),
      })
    )

    await Promise.all(promises)

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    )
  }
})
```

### 6.4 Get Firebase Server Key

1. Di **Firebase Console** → **Project Settings** → **Cloud Messaging**
2. Copy **Server key** di bagian **Cloud Messaging API (Legacy)**
3. Jika tidak ada, enable **Cloud Messaging API (Legacy)** di Google Cloud Console

### 6.5 Set Environment Variable

```bash
# Set secret untuk edge function
supabase secrets set FIREBASE_SERVER_KEY=YOUR_FIREBASE_SERVER_KEY
```

### 6.6 Deploy Edge Function

```bash
# Deploy function
supabase functions deploy send-push-notification
```

## Step 7: Update NotificationService

Update `lib/features/notifications/services/notification_service.dart` untuk call edge function:

```dart
// Add method to send push notification via edge function
Future<void> _sendPushNotification({
  required List<String> userIds,
  required String title,
  required String body,
  required String billId,
}) async {
  try {
    // Get FCM tokens for users
    final tokensResponse = await _supabase
        .from('user_devices')
        .select('fcm_token')
        .inFilter('user_id', userIds);

    final fcmTokens = (tokensResponse as List)
        .map((device) => device['fcm_token'] as String)
        .toList();

    if (fcmTokens.isEmpty) {
      print('⚠️ No FCM tokens found for users');
      return;
    }

    // Call edge function to send push notification
    await _supabase.functions.invoke('send-push-notification',
        body: {
          'fcmTokens': fcmTokens,
          'title': title,
          'body': body,
          'data': {'bill_id': billId},
        });

    print('✅ Push notification sent to ${fcmTokens.length} devices');
  } catch (e) {
    print('❌ Error sending push notification: $e');
  }
}
```

Lalu update `sendBillFinalizedNotification()`:

```dart
Future<void> sendBillFinalizedNotification({
  required String billId,
  required String billName,
  required List<String> userIds,
}) async {
  try {
    // Create notifications in database
    final notifications = userIds.map((userId) {
      return {
        'user_id': userId,
        'title': 'Bill Finalized',
        'message': 'The bill "$billName" has been finalized. Please proceed with payment to the host.',
        'type': 'bill_finalized',
        'related_id': billId,
        'is_read': false,
      };
    }).toList();

    await _supabase.from('notifications').insert(notifications);
    
    // Send push notification
    await _sendPushNotification(
      userIds: userIds,
      title: 'Bill Finalized',
      body: 'The bill "$billName" has been finalized. Please proceed with payment to the host.',
      billId: billId,
    );

    print('✅ Notifications sent to ${userIds.length} users');
  } catch (e) {
    throw Exception('Failed to send notifications: $e');
  }
}
```

## Step 8: Test

1. **Run SQL** di Supabase untuk create `user_devices` table
2. **Copy `google-services.json`** ke `android/app/`
3. **Update `build.gradle.kts`** files
4. **Update `AndroidManifest.xml`**
5. **Run app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

6. **Test flow**:
   - Login ke app
   - Cek console: `✅ FCM Token: xxxxx`
   - Cek Supabase `user_devices` table: should have entry
   - Host finalize bill
   - Invited user should receive **push notification** di device (bahkan kalau app tertutup!)

## Troubleshooting

### Error: "Default FirebaseApp is not initialized"
- Pastikan `google-services.json` ada di `android/app/`
- Run `flutter clean` dan rebuild

### No notification received
- Cek FCM token tersimpan di Supabase `user_devices`
- Cek Firebase Server Key sudah benar
- Test manual dengan Postman ke FCM API
- Cek logcat: `adb logcat | grep -i firebase`

### Android 13+ notification permission
- App akan auto-request permission saat `FCMService().initialize()`
- User harus allow notification permission

## Summary

✅ Firebase project created  
✅ `google-services.json` downloaded  
✅ Android config updated  
✅ FCM service implemented  
✅ `user_devices` table created  
✅ Edge function deployed  
✅ NotificationService updated  
✅ Push notifications working! 🎉

Sekarang app bisa **push notification** ke device users, bahkan kalau app tertutup atau di background!
