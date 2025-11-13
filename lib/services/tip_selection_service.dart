import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tip_selection_model.dart';

class TipService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _tableName = 'selecao';

  String _formatDoubleForSupabase(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  Future<int> _findIdByValue(String table, String column, double value) async {
    dynamic filterValue = value;

    if (column == 'cm') {
      filterValue = _formatDoubleForSupabase(value);
    }

    final response = await _supabase
        .from(table)
        .select('id')
        .eq(column, filterValue)
        .limit(1);

    if (response.isNotEmpty) {
      final id = response.first['id'] as int;
      return id;
    }
    return 0;
  }

  Future<List<double>> getDistinctValues(String columnName) async {
    String sourceTable;
    String sourceColumn;

    if (columnName == 'pressure') {
      sourceTable = 'pressao';
      sourceColumn = 'bar';
    } else if (columnName == 'flow_rate') {
      sourceTable = 'vazao';
      sourceColumn = 'litros';
    } else if (columnName == 'spacing') {
      sourceTable = 'espacamento';
      sourceColumn = 'cm';
    } else {
      return [];
    }

    try {
      PostgrestList response;

      response = await _supabase
          .from(sourceTable)
          .select(sourceColumn)
          .order(sourceColumn, ascending: true);

      final uniqueValues = response
          .map<double>((json) {
            final value = json[sourceColumn];

            if (value is String) {
              if (sourceTable == 'espacamento' &&
                  value.toLowerCase().contains('35')) {
                return 35.0;
              }

              return double.tryParse(value) ?? 0.0;
            }
            return (value is num ? value.toDouble() : 0.0);
          })
          .toSet()
          .toList();

      uniqueValues.sort();

      return uniqueValues;
    } on PostgrestException {
      return [];
    }
  }

  Future<List<TipModel>> searchTips({
    required double pressureValue,
    required double flowRateValue,
    required double spacingValue,
    required int applicationType,
    required int application,
    required int actionMode,
    required int pwmId,
  }) async {
    try {
      final int pressaoId =
          await _findIdByValue('pressao', 'bar', pressureValue);
      final int vazaoId =
          await _findIdByValue('vazao', 'litros', flowRateValue);
      final int spacingId =
          await _findIdByValue('espacamento', 'cm', spacingValue);

      if (pressaoId == 0 || vazaoId == 0 || spacingId == 0) {
        return [];
      }

      final PostgrestList response = await _supabase
          .from(_tableName)
          .select(
              '*, image_url, pontas(ponta), pressao(bar, psi), vazao(litros), espacamento(cm), tipo_aplicacao(tipo_aplicacao), aplicacao(aplicacao), modo_acao(modo_acao), pwm(pwm)') // Adicionado 'image_url'
          .eq('tipo_aplicacao_id', applicationType)
          .eq('aplicacao_id', application)
          .eq('modo_acao_id', actionMode)
          .eq('pwm_id', pwmId)
          .eq('pressao_id', pressaoId)
          .eq('vazao_id', vazaoId)
          .eq('espacamento_id', spacingId)
          .order('id', ascending: true)
          .limit(10);

      return response.map((json) => TipModel.fromJson(json)).toList();
    } on PostgrestException {
      rethrow;
    }
  }
}
