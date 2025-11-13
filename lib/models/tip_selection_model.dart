class TipModel {
  final String name;
  final double flowRate;
  final double pressure;
  final double spacing;
  final String detail;
  final String? imageUrl;

  TipModel({
    required this.name,
    required this.flowRate,
    required this.pressure,
    required this.spacing,
    required this.detail,
    this.imageUrl,
  });

  static String _getNestedString(Map<String, dynamic> json, String key,
      String subkey, String defaultValue) {
    final nestedObject = json[key] as Map<String, dynamic>?;
    return (nestedObject != null)
        ? (nestedObject[subkey] as String?) ?? defaultValue
        : defaultValue;
  }

  static double _getNestedDouble(
      Map<String, dynamic> json, String key, String subkey) {
    final nestedObject = json[key] as Map<String, dynamic>?;
    if (nestedObject != null) {
      final value = nestedObject[subkey];

      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      if (value is num) {
        return value.toDouble();
      }
    }
    return 0.0;
  }

  factory TipModel.fromJson(Map<String, dynamic> json) {
    final name =
        _getNestedString(json, 'pontas', 'ponta', 'Ponta Desconhecida');

    final flowRate = _getNestedDouble(json, 'vazao', 'litros');

    final pressure = _getNestedDouble(json, 'pressao', 'bar');

    final spacing = _getNestedDouble(json, 'espacamento', 'cm');

    final detail = _getNestedString(json, 'pwm', 'pwm', 'Não se aplica');

    final imageUrl = json['image_url'] as String?;

    return TipModel(
      name: name,
      flowRate: flowRate,
      pressure: pressure,
      spacing: spacing,
      detail: detail,
      imageUrl: imageUrl,
    );
  }
}
