import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<SupabaseClient?> initialize() async {
    if (!isConfigured) return null;
    await Supabase.initialize(url: url, anonKey: anonKey);
    return Supabase.instance.client;
  }
}