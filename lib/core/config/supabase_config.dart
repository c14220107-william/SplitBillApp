import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://wpvncmajhozcfahgiscx.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indwdm5jbWFqaG96Y2ZhaGdpc2N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MTA0MzEsImV4cCI6MjA3OTI4NjQzMX0.lSrAtN6Q5kGHLQ5qCTldGgCTl9wtEa-9UG-2xT8iNwk';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
