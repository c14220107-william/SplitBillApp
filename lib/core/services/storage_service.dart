import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splitbillapp/core/config/supabase_config.dart';

class StorageService {
  static final _client = SupabaseConfig.client;

  // Upload avatar to 'avatars' bucket
  static Future<String> uploadAvatar(File file, String userId) async {
    final fileExt = file.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = '$userId/$fileName'; // userId folder structure for RLS policy

    await _client.storage.from('avatars').upload(
      filePath,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);
    return publicUrl;
  }

  // Upload payment proof to 'payment_proofs' bucket
  static Future<String> uploadPaymentProof(File file, String userId, String billId) async {
    final fileExt = file.path.split('.').last;
    final fileName = '$billId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = '$userId/$fileName'; // userId folder structure for RLS policy

    await _client.storage.from('payment_proofs').upload(
      filePath,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = _client.storage.from('payment_proofs').getPublicUrl(filePath);
    return publicUrl;
  }

  // Delete file from bucket
  static Future<void> deleteFile(String bucket, String filePath) async {
    final fileName = filePath.split('/').last;
    await _client.storage.from(bucket).remove([fileName]);
  }
}
