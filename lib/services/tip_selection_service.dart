import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tip_selection_model.dart';
import 'dart:developer';

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

  double _calculateTotalDifference(TipModel tip, double targetPressure,
      double targetFlowRate, double targetSpacing) {
    final pressureDiff = (tip.pressure - targetPressure).abs();
    final flowRateDiff = (tip.flowRate - targetFlowRate).abs();
    final spacingDiff = (tip.spacing - targetSpacing).abs();

    return pressureDiff * 1.0 + flowRateDiff * 1.0 + spacingDiff * 0.5;
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
      await debugExistingValues();

      final pressaoIds = await _findIdsByValueWithTolerance(
        'pressao',
        'bar',
        pressureValue,
        absoluteTolerance: 0.5,
        percentTolerance: 10,
      );

      final vazaoIds = await _findIdsByValueWithTolerance(
        'vazao',
        'litros',
        flowRateValue,
        absoluteTolerance: 0.5,
        percentTolerance: 10,
      );

      final spacingIds = await _findIdsByValueWithTolerance(
        'espacamento',
        'cm',
        spacingValue,
        absoluteTolerance: 10,
        percentTolerance: 20,
      );

      if (pressaoIds.isEmpty || vazaoIds.isEmpty || spacingIds.isEmpty) {
        return [];
      }

      final response = await _supabase
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
          .inFilter('pressao_id', pressaoIds)
          .inFilter('vazao_id', vazaoIds)
          .inFilter('espacamento_id', spacingIds)
          .order('id', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      final allTips = response.map((json) => TipModel.fromJson(json)).toList();

      final filteredTips = _filterTipsByModel(
          allTips, pressureValue, flowRateValue, spacingValue);

      return filteredTips;
    } catch (e) {
      rethrow;
    }
  }

  List<TipModel> _filterTipsByModel(
    List<TipModel> allTips,
    double targetPressure,
    double targetFlowRate,
    double targetSpacing,
  ) {
    final modelGroups = <String, List<TipModel>>{};

    for (var tip in allTips) {
      final modelName = tip.model;
      if (!modelGroups.containsKey(modelName)) {
        modelGroups[modelName] = [];
      }
      modelGroups[modelName]!.add(tip);
    }

    final result = <TipModel>[];

    modelGroups.forEach((model, tips) {
      if (tips.length == 1) {
        result.add(tips.first);
      } else {
        TipModel closestTip = tips.first;
        double smallestDifference = _calculateTotalDifference(
            closestTip, targetPressure, targetFlowRate, targetSpacing);

        for (var tip in tips.skip(1)) {
          final difference = _calculateTotalDifference(
              tip, targetPressure, targetFlowRate, targetSpacing);
          if (difference < smallestDifference) {
            smallestDifference = difference;
            closestTip = tip;
          }
        }
        result.add(closestTip);
      }
    });

    result.sort((a, b) {
      final diffA = _calculateTotalDifference(
          a, targetPressure, targetFlowRate, targetSpacing);
      final diffB = _calculateTotalDifference(
          b, targetPressure, targetFlowRate, targetSpacing);
      return diffA.compareTo(diffB);
    });

    return result;
  }

  Future<List<double>> getDistinctValues(String field) async {
    final tableMap = {
      'pressao': 'pressao',
      'vazao': 'vazao',
      'espacamento': 'espacamento',
    };

    final columnMap = {
      'pressao': 'bar',
      'vazao': 'litros',
      'espacamento': 'cm',
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

      if (field == 'pressao' || field == 'vazao') {
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

  Future<void> debugExistingValues() async {
    final tables = [
      {'name': 'pressao', 'column': 'bar'},
      {'name': 'vazao', 'column': 'litros'},
      {'name': 'espacamento', 'column': 'cm'},
    ];

    for (var table in tables) {
      try {
        final response = await _supabase
            .from(table['name']!)
            .select('id, ${table['column']}')
            .order('id');

        if (response.isNotEmpty) {
        } else {}
      } catch (e) {
        log('Error in debugExistingValues: \$e');
      }
    }
  }
}
