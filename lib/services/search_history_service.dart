import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/search_history_model.dart';

class SearchHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> saveSearchHistory({
    required String parametersJson,
    required String resultsJson,
    required int resultCount,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('search_history').insert({
        'user_id': user.id,
        'parameters_json': parametersJson,
        'results_json': resultsJson,
        'search_date': DateTime.now().toIso8601String(),
        'result_count': resultCount,
      });
    } catch (_) {}
  }

  Future<List<SearchHistoryModel>> getUserSearchHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('search_history')
          .select()
          .eq('user_id', user.id)
          .order('search_date', ascending: false);

      return (response as List)
          .map((item) => SearchHistoryModel.fromJson(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteSearchHistory(int id) async {
    try {
      await _supabase.from('search_history').delete().eq('id', id);
    } catch (_) {}
  }

  Future<void> clearAllSearchHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('search_history').delete().eq('user_id', user.id);
    } catch (_) {}
  }
}
