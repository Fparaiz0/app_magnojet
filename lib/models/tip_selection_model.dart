class TipModel {
  final int id;
  final String name;
  final String model;
  final double pressure;
  final double flowRate;
  final double spacing;
  final double speed;
  final String? imageUrl;

  TipModel({
    required this.id,
    required this.name,
    required this.model,
    required this.pressure,
    required this.flowRate,
    required this.spacing,
    required this.speed,
    this.imageUrl,
  });

  factory TipModel.fromJson(Map<String, dynamic> json) {
    return TipModel(
      id: _parseInt(json['id']),
      name: _parseString(json['pontas']?['ponta']),
      model: _parseString(json['modelo']?['modelo']),
      pressure: _parseDouble(json['pressao']?['bar']),
      flowRate: _parseDouble(json['vazao']?['litros']),
      spacing: _parseDouble(json['espacamento']?['cm']),
      speed: _parseDouble(json['velocidade']?['km_h']),
      imageUrl: _parseString(json['image_url']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final buffer = StringBuffer();
      bool hasDecimalPoint = false;

      for (final char in value.runes) {
        final character = String.fromCharCode(char);

        if (character == '-' && buffer.isEmpty) {
          buffer.write(character);
        } else if (character == '.' && !hasDecimalPoint) {
          buffer.write(character);
          hasDecimalPoint = true;
        } else if (character == ',') {
          if (!hasDecimalPoint) {
            buffer.write('.');
            hasDecimalPoint = true;
          }
        } else if (character.codeUnitAt(0) >= 48 &&
            character.codeUnitAt(0) <= 57) {
          buffer.write(character);
        }
      }

      final resultString = buffer.toString();

      if (resultString.isEmpty || resultString == '-' || resultString == '-.') {
        return 0.0;
      }

      return double.tryParse(resultString) ?? 0.0;
    }
    return 0.0;
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}
