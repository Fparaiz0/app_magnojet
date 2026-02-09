import 'package:magnojet/models/tip_selection_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TipService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _tableName = 'selecao';

  double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      final cleanedValue = value.replaceAll(',', '.');
      return double.tryParse(cleanedValue) ?? 0.0;
    }
    return 0.0;
  }

  Future<List<int>> _findIdsByValueWithTolerance(
    String table,
    String column,
    double value, {
    double absoluteTolerance = 0.5,
    double percentTolerance = 10.0,
  }) async {
    final absoluteToleranceValue = absoluteTolerance;
    final percentToleranceValue = value * (percentTolerance / 100);
    final tolerance = absoluteToleranceValue > percentToleranceValue
        ? absoluteToleranceValue
        : percentToleranceValue;

    final minValue = (value - tolerance).clamp(0.1, double.infinity);
    final maxValue = value + tolerance;

    try {
      final response = await _supabase
          .from(table)
          .select('id, $column')
          .gte(column, minValue)
          .lte(column, maxValue)
          .order(column);

      final ids = <int>[];
      for (var item in response) {
        final itemId = item['id'] as int;
        ids.add(itemId);
      }

      return ids;
    } catch (e) {
      return [];
    }
  }

  Future<List<int>> _findVazaoIdsWithPriority(
    double flowRateValue, {
    double primaryTolerance = 0.0,
    double secondaryTolerance = 0.01,
  }) async {
    try {
      final preciseResponse = await _supabase
          .from('vazao')
          .select('id, litros')
          .gte('litros', flowRateValue - 0.001)
          .lte('litros', flowRateValue + 0.001)
          .order('litros');

      if (preciseResponse.isNotEmpty) {
        return preciseResponse.map((item) => item['id'] as int).toList();
      }

      final allValues =
          await _supabase.from('vazao').select('id, litros').order('litros');

      if (allValues.isNotEmpty) {
        double closestDiff = double.infinity;
        int closestId = -1;

        for (var item in allValues) {
          final litros = _parseDouble(item['litros']);
          final diff = (litros - flowRateValue).abs();

          if (diff < closestDiff) {
            closestDiff = diff;
            closestId = item['id'] as int;
          }
        }

        return closestId != -1 ? [closestId] : [];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  double _calculateFlowRateSimilarity(TipModel tip, double targetFlowRate) {
    final diff = (tip.flowRate - targetFlowRate).abs();
    final percentDiff = diff / targetFlowRate;

    return 1.0 / (1.0 + percentDiff * 10.0);
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
      final vazaoIds = await _findVazaoIdsWithPriority(
        flowRateValue,
        primaryTolerance: 0.5,
        secondaryTolerance: 1.0,
      );

      final pressaoIds = await _findIdsByValueWithTolerance(
        'pressao',
        'bar',
        pressureValue,
        absoluteTolerance: 2.0,
        percentTolerance: 15,
      );

      final spacingIds = await _findIdsByValueWithTolerance(
        'espacamento',
        'cm',
        spacingValue,
        absoluteTolerance: 20,
        percentTolerance: 25,
      );

      if (vazaoIds.isEmpty) {
        return [];
      }

      final query = _supabase
          .from(_tableName)
          .select('''
            *, 
            image_url, 
            pontas(ponta), 
            pressao(bar), 
            vazao(litros), 
            espacamento(cm), 
            tipo_aplicacao(tipo_aplicacao), 
            aplicacao(aplicacao), 
            modo_acao(modo_acao), 
            pwm(pwm), 
            modelo(modelo)
          ''')
          .eq('tipo_aplicacao_id', applicationType)
          .eq('aplicacao_id', application)
          .eq('modo_acao_id', actionMode)
          .eq('pwm_id', pwmId)
          .inFilter('vazao_id', vazaoIds);

      if (pressaoIds.isNotEmpty) {
        query.inFilter('pressao_id', pressaoIds);
      }
      if (spacingIds.isNotEmpty) {
        query.inFilter('espacamento_id', spacingIds);
      }

      final response = await query.order('id', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      final allTips = response.map((json) => TipModel.fromJson(json)).toList();

      final filteredTips = _filterTipsByFlowRatePriority(
          allTips, pressureValue, flowRateValue, spacingValue);

      return filteredTips;
    } catch (e) {
      rethrow;
    }
  }

  List<TipModel> _filterTipsByFlowRatePriority(
    List<TipModel> allTips,
    double targetPressure,
    double targetFlowRate,
    double targetSpacing,
  ) {
    final tipGroups = <String, List<TipModel>>{};

    for (var tip in allTips) {
      final key = '${tip.name}_${tip.model}';

      if (!tipGroups.containsKey(key)) {
        tipGroups[key] = [];
      }
      tipGroups[key]!.add(tip);
    }

    final result = <TipModel>[];

    tipGroups.forEach((key, tips) {
      if (tips.length == 1) {
        result.add(tips.first);
      } else {
        TipModel bestFlowRateTip = tips.first;
        double bestFlowRateSimilarity =
            _calculateFlowRateSimilarity(bestFlowRateTip, targetFlowRate);

        for (var tip in tips.skip(1)) {
          final similarity = _calculateFlowRateSimilarity(tip, targetFlowRate);
          if (similarity > bestFlowRateSimilarity) {
            bestFlowRateSimilarity = similarity;
            bestFlowRateTip = tip;
          }
        }
        result.add(bestFlowRateTip);
      }
    });

    result.sort((a, b) {
      final similarityA = _calculateFlowRateSimilarity(a, targetFlowRate);
      final similarityB = _calculateFlowRateSimilarity(b, targetFlowRate);
      return similarityB.compareTo(similarityA);
    });

    return result;
  }

  Future<List<double>> getDistinctValues(String field) async {
    final tableMap = {
      'pressao': 'pressao',
      'vazao': 'vazao',
      'espacamento': 'espacamento',
      'velocidade': 'velocidade',
    };

    final columnMap = {
      'pressao': 'bar',
      'vazao': 'litros',
      'espacamento': 'cm',
      'velocidade': 'km_h',
    };

    final actualTable = tableMap[field];
    final actualColumn = columnMap[field];

    if (actualTable == null || actualColumn == null) {
      return [];
    }

    try {
      final response = await _supabase
          .from(actualTable)
          .select('id, $actualColumn')
          .order(actualColumn, ascending: true);

      var values = response
          .map<double>((json) {
            final value = json[actualColumn];
            final result = _parseDouble(value);
            return result;
          })
          .where((value) => value > 0)
          .toSet()
          .toList();

      values.sort();

      if (field == 'pressao') {
        values = _filterValuesByIncrement(values, 0.1);
      } else if (field == 'vazao' ||
          field == 'espacamento' ||
          field == 'velocidade') {
        values = _filterValuesByIncrement(values, 0.5);
      }

      return values;
    } catch (e) {
      return [];
    }
  }

  List<double> _filterValuesByIncrement(List<double> values, double increment) {
    if (values.isEmpty) return [];

    final filteredValues = <double>[];
    double lastAddedValue = values.first - increment;

    for (var value in values) {
      final roundedValue = (value * 2).round() / 2;

      if ((roundedValue - lastAddedValue) >= increment - 0.01) {
        filteredValues.add(roundedValue);
        lastAddedValue = roundedValue;
      }
    }

    return filteredValues;
  }
}
