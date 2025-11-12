import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  /// Helper to call RPC and return the returned list (or null)
  Future<List<Map<String, dynamic>>?> callRpc(String name, Map<String, dynamic> params) async {
    final res = await client.rpc(name, params: params);
    if (res.error != null) {
      throw res.error!;
    }
    final data = res.data as List<dynamic>?;
    if (data == null || data.isEmpty) return null;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
