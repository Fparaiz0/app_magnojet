import 'package:flutter/material.dart';
import '../../models/search_history_model.dart';
import '../../models/tip_selection_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tip_details_page.dart';

class SearchHistoryDetailPage extends StatefulWidget {
  final SearchHistoryModel history;

  const SearchHistoryDetailPage({
    super.key,
    required this.history,
  });

  @override
  State<SearchHistoryDetailPage> createState() =>
      _SearchHistoryDetailPageState();
}

class _SearchHistoryDetailPageState extends State<SearchHistoryDetailPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic> _parameters = {};
  final Map<int, String> _dropletSizeMap = {
    1: 'EF',
    2: 'MF',
    3: 'F',
    4: 'M',
    5: 'G',
    6: 'MG',
    7: 'EG',
    8: 'UG',
  };

  static const primaryColor = Color(0xFF15325A);
  static const backgroundColor = Colors.white;
  static const cardColor = Colors.white;
  static const textPrimary = Color(0xFF333333);
  static const textSecondary = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _loadHistoryDetails();
  }

  void _loadHistoryDetails() {
    try {
      _parameters = _parseParameters(widget.history.parametersJson);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _parseParameters(String jsonString) {
    final params = <String, dynamic>{};
    try {
      final cleanedString = jsonString.trim();
      final pairs = cleanedString.split(', ');
      for (final pair in pairs) {
        final keyValue = pair.split(': ');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          var value = keyValue[1].trim();
          if (value.toLowerCase() == 'true') {
            value = 'Sim';
          } else if (value.toLowerCase() == 'false') {
            value = 'Não';
          } else if (_isNumeric(value)) {
            final numValue = double.tryParse(value);
            if (numValue != null) {
              if (numValue == numValue.toInt()) {
                value = numValue.toInt().toString();
              } else {
                value = numValue.toStringAsFixed(1);
              }
            }
          }
          params[key] = value;
        }
      }
    } catch (_) {}
    return params;
  }

  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return double.tryParse(str) != null;
  }

  String _getDisplayName(String key) {
    final displayNames = {
      'application_type': 'Tipo de Aplicação',
      'application': 'Produto',
      'action_mode': 'Modo de Ação',
      'pwm': 'Tecnologia PWM',
      'pressure': 'Pressão',
      'flow_rate_per_hectare': 'Vazão por Hectare',
      'flow_rate': 'Vazão',
      'spacing': 'Espaçamento',
      'speed': 'Velocidade',
    };
    return displayNames[key] ?? key;
  }

  String _formatValue(String key, dynamic value) {
    if (value == null || value.toString().isEmpty) return 'Não informado';
    final stringValue = value.toString();
    switch (key) {
      case 'pressure':
        return '$stringValue bar';
      case 'flow_rate_per_hectare':
        return '$stringValue L/ha';
      case 'flow_rate':
        return '$stringValue L/min';
      case 'spacing':
        return '$stringValue cm';
      case 'speed':
        return '$stringValue km/h';
      case 'pwm':
        return stringValue == 'Sim' ? 'Ativado' : 'Desativado';
      default:
        return stringValue;
    }
  }

  Widget _buildParameterItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (widget.history.resultCount == null || widget.history.resultCount == 0) {
      return _buildEmptyResults('Nenhum resultado encontrado nesta busca');
    }

    try {
      final resultsJson = widget.history.resultsJson;
      if (resultsJson.isEmpty) {
        return _buildEmptyResults('Resultados não disponíveis');
      }

      final results = resultsJson.split(';');
      final List<Map<String, dynamic>> tipList = [];

      for (final result in results) {
        final parts = result.split('|');
        if (parts.length >= 8) {
          tipList.add({
            'id': int.tryParse(parts[0]) ?? 0,
            'name': parts[1],
            'model': parts[2],
            'flowRate': double.tryParse(parts[3]) ?? 0.0,
            'pressure': double.tryParse(parts[4]) ?? 0.0,
            'spacing': double.tryParse(parts[5]) ?? 0.0,
            'dropletSizeId': int.tryParse(parts[6]) ?? 0,
            'imageUrl': parts[7],
          });
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...tipList.map((tipData) => _buildResultCard(tipData)),
        ],
      );
    } catch (e) {
      return _buildEmptyResults('Erro ao carregar resultados');
    }
  }

  Widget _buildResultCard(Map<String, dynamic> tipData) {
    final dropletSize = _dropletSizeMap[tipData['dropletSizeId']] ?? 'N/A';
    final imageUrl = tipData['imageUrl'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _navigateToTipDetails(tipData);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasImage
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholderIcon(),
                          )
                        : _buildPlaceholderIcon(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tipData['name']} - ${tipData['model']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildInfoChip(
                                      '${tipData['flowRate']} L/min',
                                      Icons.speed_rounded,
                                    ),
                                    _buildInfoChip(
                                      '${tipData['pressure']} bar',
                                      Icons.compress_rounded,
                                    ),
                                    _buildInfoChip(
                                      '${tipData['spacing']} cm',
                                      Icons.straighten_rounded,
                                    ),
                                    _buildInfoChip(
                                      dropletSize,
                                      Icons.water_drop_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clique para ver detalhes completos',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.agriculture_outlined,
        size: 32,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildEmptyResults(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 40,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTipDetails(Map<String, dynamic> tipData) {
    final hasPWM = _parameters['pwm'] == 'Ativado';
    final speed = double.tryParse(
            _parameters['speed']?.toString().split(' ')[0] ?? '12.0') ??
        12.0;

    final tip = TipModel(
      id: tipData['id'] as int,
      name: tipData['name'] as String,
      model: tipData['model'] as String,
      flowRate: tipData['flowRate'] as double,
      pressure: tipData['pressure'] as double,
      spacing: tipData['spacing'] as double,
      dropletSizeId: tipData['dropletSizeId'] as int,
      imageUrl: tipData['imageUrl'] as String?,
      speed: speed,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TipDetailsPage(
          tip: tip,
          dropletSizeMap: _dropletSizeMap,
          speed: speed,
          hasPWM: hasPWM,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Busca - ${_formatDate(widget.history.searchDate)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parâmetros da Busca',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_parameters.isNotEmpty)
                            Column(
                              children: _parameters.entries.map((entry) {
                                final displayName = _getDisplayName(entry.key);
                                final formattedValue =
                                    _formatValue(entry.key, entry.value);
                                return _buildParameterItem(
                                    displayName, formattedValue);
                              }).toList(),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Parâmetros não disponíveis',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Resultados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${widget.history.resultCount ?? 0} encontrados',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildResultsSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return 'Hoje às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ontem às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
