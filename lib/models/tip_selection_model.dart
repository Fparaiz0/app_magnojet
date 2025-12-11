class TipModel {
  final int id;
  final String name;
  final String model;
  final double pressure;
  final double flowRate;
  final double spacing;
  final double speed;
  final String? imageUrl;
  final int? dropletSizeId;
  final String? modoAcao;
  final String? aplicacao;

  TipModel({
    required this.id,
    required this.name,
    required this.model,
    required this.pressure,
    required this.flowRate,
    required this.spacing,
    required this.speed,
    this.imageUrl,
    this.dropletSizeId,
    this.modoAcao,
    this.aplicacao,
  });

  factory TipModel.fromJson(Map<String, dynamic> json) {
    dynamic extractNested(
        Map<String, dynamic> json, String key, String nestedKey) {
      final parent = json[key];
      if (parent is Map<String, dynamic>) {
        return parent[nestedKey];
      }
      return null;
    }

    dynamic extractInconsistent(Map<String, dynamic> json, String key) {
      final value = json[key];
      if (value is Map<String, dynamic>) {
        return value[key];
      }
      return value;
    }

    return TipModel(
      id: _safeParseInt(json['id']),
      name: _safeParseString(extractNested(json, 'pontas', 'ponta')),
      model: _safeParseString(extractNested(json, 'modelo', 'modelo')),
      pressure: _safeParseDouble(extractNested(json, 'pressao', 'bar')),
      flowRate: _safeParseDouble(extractNested(json, 'vazao', 'litros')),
      spacing: _safeParseDouble(extractNested(json, 'espacamento', 'cm')),
      speed: _safeParseDouble(extractNested(json, 'velocidade', 'km_h')),
      imageUrl: _safeParseString(json['image_url']),
      dropletSizeId: _safeParseInt(json['tamanho_gota_id']),
      modoAcao: _safeParseString(extractInconsistent(json, 'modo_acao')),
      aplicacao: _safeParseString(extractInconsistent(json, 'aplicacao')),
    );
  }

  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  static double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '.');

      final result = double.tryParse(cleaned);
      if (result != null) return result;

      final buffer = StringBuffer();
      for (final char in cleaned.runes) {
        final c = String.fromCharCode(char);
        if (c == '-' && buffer.isEmpty) {
          buffer.write(c);
        } else if (c == '.') {
          buffer.write(c);
        } else if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
          buffer.write(c);
        }
      }
      return double.tryParse(buffer.toString()) ?? 0.0;
    }
    return 0.0;
  }

  static String _safeParseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}
