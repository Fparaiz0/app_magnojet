import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../models/tip_selection_model.dart';
import '../services/tip_selection_service.dart';

class TipSelectionPage extends StatefulWidget {
  const TipSelectionPage({super.key});

  @override
  State<TipSelectionPage> createState() => _TipSelectionPageState();
}

class _TipSelectionPageState extends State<TipSelectionPage> {
  final TipService _tipService = TipService();

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  double _pressure = 0.0;
  double _flowRate = 0.0;
  double _spacing = 0.0;

  List<double> _availablePressures = [];
  List<double> _availableFlowRates = [];
  List<double> _availableSpacings = [];

  String? _selectedApplicationType = 'Aplicação em Solo';
  String? _selectedApplication = 'Herbicida';
  String? _selectedActionMode = 'Sistemico';
  bool _hasPWM = false;

  bool _showResults = false;
  bool _isLoading = false;
  List<TipModel> _recommendedTips = [];

  final Map<String, ImageProvider> _imageCache = {};

  static const primaryColor = Color(0xFF15325A);
  static const secondaryColor = Color(0xFFE8F0F8);

  final Map<String, int> _applicationTypeToId = {
    'Aplicação em Solo': 1,
    'Florestal': 2,
    'Aplicação Seletiva': 3,
    'Área Total': 4,
    'Barra Curta': 5,
    'Conforto Térmico': 6,
    'Turbo Atomizador': 7,
  };

  final Map<String, int> _applicationToId = {
    'Fungicida': 1,
    'Herbicida': 2,
    'Inseticida': 3,
  };

  final Map<String, int> _actionModeToId = {
    'Sistemico': 1,
    'Contato': 2,
    'Não se aplica': 3,
  };

  final List<Map<String, dynamic>> _applicationTypes = [
    {'name': 'Aplicação em Solo', 'icon': Icons.agriculture_rounded},
    {'name': 'Florestal', 'icon': Icons.forest_rounded},
    {'name': 'Aplicação Seletiva', 'icon': Icons.my_location_rounded},
    {'name': 'Área Total', 'icon': Icons.grass_rounded},
    {'name': 'Barra Curta', 'icon': Icons.water_drop_rounded},
    {'name': 'Conforto Térmico', 'icon': MdiIcons.cow},
    {
      'name': 'Turbo Atomizador',
      'icon': Icons.settings_input_component_rounded
    },
  ];

  final List<Map<String, dynamic>> _applications = [
    {'name': 'Fungicida', 'icon': Icons.science_rounded},
    {'name': 'Herbicida', 'icon': Icons.eco_rounded},
    {'name': 'Inseticida', 'icon': Icons.bug_report_rounded},
  ];

  final List<Map<String, dynamic>> _actionModes = [
    {'name': 'Sistemico', 'icon': Icons.spa_rounded},
    {'name': 'Contato', 'icon': Icons.touch_app_rounded},
    {'name': 'Não se aplica', 'icon': Icons.cancel_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadDistinctValues();
  }

  @override
  void dispose() {
    _imageCache.clear();
    super.dispose();
  }

  Future<void> _loadDistinctValues() async {
    final pressures = await _tipService.getDistinctValues('pressao');
    final flows = await _tipService.getDistinctValues('vazao');
    final spacings = await _tipService.getDistinctValues('espacamento');

    setState(() {
      _availablePressures = _filterValuesByIncrement(pressures, 0.5);
      _availableFlowRates = _filterValuesByIncrement(flows, 0.5);
      _availableSpacings = spacings;

      _pressure =
          _availablePressures.isNotEmpty ? _availablePressures.first : 3.0;
      _flowRate =
          _availableFlowRates.isNotEmpty ? _availableFlowRates.first : 0.8;
      _spacing =
          _availableSpacings.isNotEmpty ? _availableSpacings.first : 35.0;
    });
  }

  List<double> _filterValuesByIncrement(List<double> values, double increment) {
    if (values.isEmpty) return [];

    values.sort();
    final filteredValues = <double>[];
    double lastAddedValue = values.first - increment;

    for (var value in values) {
      if ((value - lastAddedValue) >= increment - 0.01) {
        filteredValues.add(value);
        lastAddedValue = value;
      }
    }

    return filteredValues;
  }

  Future<void> _searchTips() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApplicationType == null ||
        _selectedApplication == null ||
        _selectedActionMode == null) {
      return;
    }

    final int applicationTypeId =
        _applicationTypeToId[_selectedApplicationType!] ?? 0;
    final int applicationCId = _applicationToId[_selectedApplication!] ?? 0;
    final int actionModeId = _actionModeToId[_selectedActionMode!] ?? 0;
    final int pwmId = _hasPWM ? 1 : 2;

    if (_pressure == 0.0 || _flowRate == 0.0 || _spacing == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Selecione uma Pressão, Vazão e Espaçamento válidos.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showResults = false;
      _recommendedTips = [];
    });

    try {
      final results = await _tipService.searchTips(
        pressureValue: _pressure,
        flowRateValue: _flowRate,
        spacingValue: _spacing,
        applicationType: applicationTypeId,
        application: applicationCId,
        actionMode: actionModeId,
        pwmId: pwmId,
      );

      if (!mounted) return;
      _preloadImages(results);

      setState(() {
        _recommendedTips = results;
        _isLoading = false;
        _showResults = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 50,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showResults = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString().split(':')[0]}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _preloadImages(List<TipModel> tips) {
    for (final tip in tips) {
      if (tip.imageUrl != null && tip.imageUrl!.isNotEmpty) {
        if (!_imageCache.containsKey(tip.imageUrl!)) {
          final imageProvider = NetworkImage(tip.imageUrl!);
          _imageCache[tip.imageUrl!] = imageProvider;
          precacheImage(imageProvider, context).catchError((_) {});
        }
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedApplicationType = 'Aplicação em Solo';
      _selectedApplication = 'Herbicida';
      _selectedActionMode = 'Sistemico';
      _hasPWM = false;
      _showResults = false;
      _recommendedTips = [];

      if (_availablePressures.isNotEmpty) _pressure = _availablePressures.first;
      if (_availableFlowRates.isNotEmpty) _flowRate = _availableFlowRates.first;
      if (_availableSpacings.isNotEmpty) _spacing = _availableSpacings.first;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildIconSelectionButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required double width,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 80,
        width: width,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primaryColor : Colors.black87,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.8)
                      : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSelection({
    required String label,
    required double currentValue,
    required String unit,
    required IconData icon,
    required List<double> options,
    required ValueChanged<double> onChanged,
  }) {
    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nenhum valor disponível',
                  style: TextStyle(color: Colors.grey),
                ),
                Icon(Icons.warning_amber_rounded, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
          ),
          child: DropdownButtonFormField<double>(
            initialValue: currentValue,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            dropdownColor: Colors.white,
            items: options.map((double value) {
              return DropdownMenuItem<double>(
                value: value,
                child: Text(
                  _formatExactValue(value, unit),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
            onChanged: (double? newValue) {
              if (newValue != null) {
                onChanged(newValue);
                setState(() {
                  _showResults = false;
                });
              }
            },
            validator: (value) {
              if (value == null || value == 0.0) {
                return 'Selecione um valor de $label';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatExactValue(double value, String unit) {
    if (value == value.toInt().toDouble()) {
      return '${value.toInt()} $unit';
    }
    final String stringValue = value.toString();
    final int decimalPlaces = stringValue.split('.').last.length;

    if (decimalPlaces <= 2) {
      return '${value.toStringAsFixed(decimalPlaces)} $unit';
    } else {
      return '${value.toStringAsFixed(2)} $unit';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 32),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    if (!_showResults) {
      return const SizedBox.shrink();
    }

    if (_recommendedTips.isEmpty) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 40, color: Colors.orange.shade700),
              const SizedBox(height: 10),
              const Text(
                'Nenhuma ponta encontrada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tente ajustar para ampliar os resultados da busca.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Pontas Recomendadas', Icons.verified_rounded,
              subtitle:
                  'Baseado nos parâmetros informados (${_recommendedTips.length} resultados)'),
          ..._recommendedTips.map((tip) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Semantics(
                button: true,
                label: 'Detalhes da ponta ${tip.name}',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: 'Imagem da ponta ${tip.name}',
                        child: Container(
                          width: 100,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              tip.imageUrl ?? '',
                              width: 100,
                              height: 140,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey.shade100,
                                child: const Icon(
                                  Icons.agriculture_outlined,
                                  size: 36,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    '${tip.name} - ${tip.model}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildInfoChip(
                                  _formatExactValue(tip.flowRate, 'L/min'),
                                  Icons.speed_rounded,
                                ),
                                _buildInfoChip(
                                  _formatExactValue(tip.pressure, 'bar'),
                                  Icons.compress_rounded,
                                ),
                                _buildInfoChip(
                                  _formatExactValue(tip.spacing, 'cm'),
                                  Icons.straighten_rounded,
                                ),
                                _buildInfoChip(
                                  _hasPWM ? 'Sim' : 'Não',
                                  Icons.flash_on_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        label: 'Clique para mais detalhes',
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Center(
            child: Semantics(
              button: true,
              label: 'Realizar nova busca de pontas',
              child: TextButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Nova Busca'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return _isLoading
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(color: primaryColor),
                SizedBox(height: 16),
                Text(
                  'Buscando pontas, aguarde...',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Seleção de Pontas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Ajuda'),
                  content: const Text(
                    'Preencha todos os campos para encontrar as pontas mais adequadas para sua aplicação. Os valores de Pressão e Vazão são utilizados para filtrar pontas que suportam o valor até 0.50 para cima e para baixo.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                                'Tipo de Aplicação', Icons.category_rounded,
                                subtitle:
                                    'Selecione o tipo de aplicação desejada'),
                            const SizedBox(height: 16),
                            _buildResponsiveButtonGrid(
                              items: _applicationTypes,
                              selectedValue: _selectedApplicationType,
                              onSelected: (value) {
                                setState(() {
                                  _selectedApplicationType = value;
                                  _showResults = false;
                                });
                              },
                              crossAxisCount: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                                'Filtros de Produto e Tecnologia',
                                Icons.filter_alt_rounded,
                                subtitle:
                                    'Configure o produto e a tecnologia utilizada'),
                            const SizedBox(height: 20),
                            const Text(
                              'Tipo de Produto',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildResponsiveButtonGrid(
                              items: _applications,
                              selectedValue: _selectedApplication,
                              onSelected: (value) {
                                setState(() {
                                  _selectedApplication = value;
                                  _showResults = false;
                                });
                              },
                              crossAxisCount: 3,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Modo de Ação / Tecnologia',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildResponsiveButtonGrid(
                              items: [
                                ..._actionModes,
                                {'name': 'PWM', 'icon': Icons.flash_on_rounded}
                              ],
                              selectedValue: _selectedActionMode,
                              isPWM: _hasPWM,
                              onSelected: (value) {
                                setState(() {
                                  if (value == 'PWM') {
                                    _hasPWM = !_hasPWM;
                                  } else {
                                    _selectedActionMode = value;
                                  }
                                  _showResults = false;
                                });
                              },
                              crossAxisCount: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildSectionHeader(
                                'Parâmetros Técnicos', Icons.tune_rounded,
                                subtitle:
                                    'Selecione a pressão, vazão e espaçamento desejadas'),
                            _buildDropdownSelection(
                              label: 'Pressão',
                              currentValue: _pressure,
                              unit: 'bar',
                              icon: Icons.compress_rounded,
                              options: _availablePressures,
                              onChanged: (newValue) => setState(() {
                                _pressure = newValue;
                              }),
                            ),
                            _buildDropdownSelection(
                              label: 'Vazão',
                              currentValue: _flowRate,
                              unit: 'L/min',
                              icon: Icons.opacity_rounded,
                              options: _availableFlowRates,
                              onChanged: (newValue) => setState(() {
                                _flowRate = newValue;
                              }),
                            ),
                            _buildDropdownSelection(
                              label: 'Espaçamento',
                              currentValue: _spacing,
                              unit: 'cm',
                              icon: Icons.straighten_rounded,
                              options: _availableSpacings,
                              onChanged: (newValue) => setState(() {
                                _spacing = newValue;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildLoadingIndicator(),
                    _buildResultSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _searchTips,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: Text(
                    _isLoading ? 'BUSCANDO...' : 'BUSCAR PONTAS',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveButtonGrid({
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String) onSelected,
    required int crossAxisCount,
    bool isPWM = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        final actualCrossAxisCount = screenWidth > 800
            ? crossAxisCount
            : screenWidth > 500
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: actualCrossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected =
                item['name'] == 'PWM' ? isPWM : item['name'] == selectedValue;

            return _buildIconSelectionButton(
              title: item['name'],
              icon: item['icon'],
              isSelected: isSelected,
              onTap: () => onSelected(item['name']),
              width: double.infinity,
            );
          },
        );
      },
    );
  }
}
