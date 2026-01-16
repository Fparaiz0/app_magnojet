import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../models/tip_selection_model.dart';
import '../../../services/tip_selection_service.dart';
import '../../../services/search_history_service.dart';
import 'home_page.dart';
import 'tip_details_page.dart';
import 'favorites_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_drawer.dart';
import '../auth/login_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'history_page.dart';
import 'catalog_page.dart';

class TipSelectionPage extends StatefulWidget {
  const TipSelectionPage({super.key});

  @override
  State<TipSelectionPage> createState() => _TipSelectionPageState();
}

class _TipSelectionPageState extends State<TipSelectionPage> {
  final TipService _tipService = TipService();
  final SearchHistoryService _historyService = SearchHistoryService();
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

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

  Set<int> _selectedDropletSizes = {};
  List<int> _availableDropletSizes = [];

  String _userName = '';
  String? _userAvatarUrl;
  bool _isLoadingUser = true;
  double _pressure = 3.0;
  double _flowRatePerHectare = 100.0;
  double _flowRate = 1.0;
  double _spacing = 50.0;
  double _speed = 12.0;

  String? _selectedApplicationType = 'Aplicação em Solo';
  String? _selectedApplication = 'Herbicida';
  String? _selectedActionMode = 'Sistemico';
  bool _hasPWM = false;

  bool _showResults = false;
  bool _isLoading = false;
  List<TipModel> _recommendedTips = [];

  final Map<String, ImageProvider> _imageCache = {};

  final TextEditingController _pressureController = TextEditingController();
  final TextEditingController _flowRatePerHectareController =
      TextEditingController();
  final TextEditingController _spacingController = TextEditingController();
  final TextEditingController _speedController = TextEditingController();

  static const primaryColor = Color(0xFF15325A);
  static const backgroundColor = Color(0xFFF5F7FA);

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
    'Não se aplica': 4,
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
    {'name': 'Não se aplica', 'icon': Icons.cancel_rounded},
  ];

  final List<Map<String, dynamic>> _actionModes = [
    {'name': 'Sistemico', 'icon': Icons.spa_rounded},
    {'name': 'Contato', 'icon': Icons.touch_app_rounded},
    {'name': 'Não se aplica', 'icon': Icons.cancel_rounded},
  ];

  List<double> _generatePressureValues() {
    final values = <double>[];
    for (double i = 1.0; i <= 150.0; i += 0.1) {
      values.add(double.parse(i.toStringAsFixed(1)));
    }
    return values;
  }

  List<double> _generateFlowRatePerHectareValues() {
    final values = <double>[];
    for (double i = 1.0; i <= 10000.0; i += 1) {
      values.add(i);
    }
    return values;
  }

  List<double> _generateSpacingValues() {
    final values = <double>[];
    for (double i = 1.0; i <= 1000.0; i += 0.5) {
      values.add(i);
    }
    return values;
  }

  List<double> _generateSpeedValues() {
    final values = <double>[];
    for (double i = 1.0; i <= 300.0; i += 1) {
      values.add(i);
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _calculateFlowRate();

    _pressureController.text = _pressure.toStringAsFixed(1);
    _flowRatePerHectareController.text = _flowRatePerHectare.toStringAsFixed(0);
    _spacingController.text = _spacing.toStringAsFixed(1);
    _speedController.text = _speed.toStringAsFixed(1);

    _pressureController.addListener(_updatePressureFromController);
    _flowRatePerHectareController.addListener(_updateFlowRateFromController);
    _spacingController.addListener(_updateSpacingFromController);
    _speedController.addListener(_updateSpeedFromController);
  }

  @override
  void dispose() {
    _pressureController.dispose();
    _flowRatePerHectareController.dispose();
    _spacingController.dispose();
    _speedController.dispose();
    _imageCache.clear();
    super.dispose();
  }

  void _updatePressureFromController() {
    final text = _pressureController.text;
    if (text.isNotEmpty) {
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value != null && value >= 0.1 && value <= 150.0) {
        if (_pressure != value) {
          setState(() {
            _pressure = value;
            _showResults = false;
          });
        }
      }
    }
  }

  void _updateFlowRateFromController() {
    final text = _flowRatePerHectareController.text;
    if (text.isNotEmpty) {
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value != null && value >= 50.0 && value <= 10000.0) {
        if (_flowRatePerHectare != value) {
          setState(() {
            _flowRatePerHectare = value;
            _showResults = false;
          });
          _calculateFlowRate();
        }
      }
    }
  }

  void _updateSpacingFromController() {
    final text = _spacingController.text;
    if (text.isNotEmpty) {
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value != null && value >= 35.0 && value <= 1000.0) {
        if (_spacing != value) {
          setState(() {
            _spacing = value;
            _showResults = false;
          });
          _calculateFlowRate();
        }
      }
    }
  }

  void _updateSpeedFromController() {
    final text = _speedController.text;
    if (text.isNotEmpty) {
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value != null && value >= 4.0 && value <= 300.0) {
        if (_speed != value) {
          setState(() {
            _speed = value;
            _showResults = false;
          });
          _calculateFlowRate();
        }
      }
    }
  }

  void _calculateFlowRate() {
    final spacingMeters = _spacing / 100.0;
    final calculated = (_flowRatePerHectare * spacingMeters * _speed) / 600;
    setState(() {
      _flowRate = double.parse(calculated.toStringAsFixed(2));
    });
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoadingUser = false);
      return;
    }

    try {
      final response = await supabase
          .from('users')
          .select('name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userName = (response?['name'] ?? 'Usuário');
          _userAvatarUrl = (response?['avatar_url']);
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar usuário: $e')),
        );
      }
    }
  }

  Future<void> _searchTips() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApplicationType == null || _selectedActionMode == null) {
      return;
    }

    final int applicationTypeId =
        _applicationTypeToId[_selectedApplicationType!] ?? 0;
    final int applicationCId =
        _applicationToId[_selectedApplication ?? 'Não se aplica'] ?? 4;
    final int actionModeId = _actionModeToId[_selectedActionMode!] ?? 0;
    final int pwmId = _hasPWM ? 1 : 2;

    if (_pressure == 0.0 ||
        _flowRate == 0.0 ||
        _spacing == 0.0 ||
        _speed == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Selecione valores válidos para todos os parâmetros.'),
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

      final availableSizes = <int>{};
      for (final tip in results) {
        if (tip.dropletSizeId != null) {
          availableSizes.add(tip.dropletSizeId!);
        }
      }

      setState(() {
        _recommendedTips = results;
        _availableDropletSizes = availableSizes.toList();
        _selectedDropletSizes = availableSizes;
        _isLoading = false;
        _showResults = true;
      });

      await _saveSearchToHistory(results);

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

  Future<void> _saveSearchToHistory(List<TipModel> results) async {
    try {
      final parameters = {
        'application_type': _selectedApplicationType,
        'application': _selectedApplication,
        'action_mode': _selectedActionMode,
        'pwm': _hasPWM,
        'pressure': _pressure.toStringAsFixed(1),
        'flow_rate_per_hectare': _flowRatePerHectare.toInt().toString(),
        'flow_rate': _flowRate.toStringAsFixed(2),
        'spacing': _spacing.toStringAsFixed(1),
        'speed': _speed.toStringAsFixed(1),
      };

      final parametersJson =
          parameters.entries.map((e) => '${e.key}: ${e.value}').join(', ');

      final resultsJson = results
          .map((tip) =>
              '${tip.id}|${tip.name}|${tip.model}|${tip.flowRate}|${tip.pressure}|'
              '${tip.spacing}|${tip.dropletSizeId ?? 0}|${tip.imageUrl ?? ""}')
          .join(';');

      await _historyService.saveSearchHistory(
        parametersJson: parametersJson,
        resultsJson: resultsJson,
        resultCount: results.length,
      );
    } catch (_) {}
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
      _pressure = 3.0;
      _flowRatePerHectare = 100.0;
      _spacing = 50.0;
      _speed = 12.0;
      _selectedDropletSizes.clear();
      _availableDropletSizes.clear();

      _pressureController.text = _pressure.toStringAsFixed(1);
      _flowRatePerHectareController.text =
          _flowRatePerHectare.toStringAsFixed(0);
      _spacingController.text = _spacing.toStringAsFixed(1);
      _speedController.text = _speed.toStringAsFixed(1);
    });
    _calculateFlowRate();
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

  Widget _buildIncrementDecrementSelection({
    required String label,
    required double currentValue,
    required String unit,
    required IconData icon,
    required List<double> options,
    required ValueChanged<double> onChanged,
    required TextEditingController controller,
  }) {
    final currentIndex = options.indexOf(currentValue);
    final canDecrement = currentIndex > 0;
    final canIncrement = currentIndex < options.length - 1;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: canDecrement
                    ? () {
                        final newValue = options[currentIndex - 1];
                        onChanged(newValue);
                        controller.text = newValue.toStringAsFixed(
                            unit == 'bar' || unit == 'cm' ? 1 : 0);
                        setState(() {
                          _showResults = false;
                        });
                      }
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: canDecrement
                      ? primaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.remove,
                  color: canDecrement ? primaryColor : Colors.grey,
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: currentValue.toStringAsFixed(
                            unit == 'bar' || unit == 'cm' ? 1 : 0),
                        hintStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final parsedValue =
                              double.tryParse(value.replaceAll(',', '.'));
                          if (parsedValue != null) {
                            double newValue = parsedValue;

                            if (label == 'Pressão') {
                              if (newValue < 1.0) newValue = 1.0;
                              if (newValue > 150.0) newValue = 150.0;
                              newValue =
                                  double.parse(newValue.toStringAsFixed(1));
                            } else if (label == 'Espaçamento') {
                              if (newValue < 35.0) newValue = 35.0;
                              if (newValue > 1000.0) newValue = 1000.0;
                              newValue =
                                  double.parse(newValue.toStringAsFixed(1));
                            } else if (label == 'Velocidade') {
                              if (newValue < 4.0) newValue = 4.0;
                              if (newValue > 300.0) newValue = 300.0;
                              newValue =
                                  double.parse(newValue.toStringAsFixed(1));
                            }

                            if (currentValue != newValue) {
                              onChanged(newValue);
                              setState(() {
                                _showResults = false;
                              });
                            }
                          }
                        }
                      },
                      onTap: () {
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: controller.text.length,
                        );
                      },
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: canIncrement
                    ? () {
                        final newValue = options[currentIndex + 1];
                        onChanged(newValue);
                        controller.text = newValue.toStringAsFixed(
                            unit == 'bar' || unit == 'cm' ? 1 : 0);
                        setState(() {
                          _showResults = false;
                        });
                      }
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: canIncrement
                      ? primaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.add,
                  color: canIncrement ? primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFlowRateSelection() {
    final options = _generateFlowRatePerHectareValues();
    final currentIndex = options.indexOf(_flowRatePerHectare);
    final canDecrement = currentIndex > 0;
    final canIncrement = currentIndex < options.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.opacity_rounded, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'Vazão',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: canDecrement
                        ? () {
                            final newValue = options[currentIndex - 1];
                            setState(() {
                              _flowRatePerHectare = newValue;
                              _flowRatePerHectareController.text =
                                  newValue.toStringAsFixed(0);
                              _showResults = false;
                            });
                            _calculateFlowRate();
                          }
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: canDecrement
                          ? primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      Icons.remove,
                      color: canDecrement ? primaryColor : Colors.grey,
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _flowRatePerHectareController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: _flowRatePerHectare.toStringAsFixed(0),
                            hintStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              final parsedValue = double.tryParse(value);
                              if (parsedValue != null) {
                                double newValue = parsedValue;
                                if (newValue < 50.0) newValue = 50.0;
                                if (newValue > 10000.0) newValue = 10000.0;

                                if (_flowRatePerHectare != newValue) {
                                  setState(() {
                                    _flowRatePerHectare = newValue;
                                    _showResults = false;
                                  });
                                  _calculateFlowRate();
                                }
                              }
                            }
                          },
                          onTap: () {
                            _flowRatePerHectareController.selection =
                                TextSelection(
                              baseOffset: 0,
                              extentOffset:
                                  _flowRatePerHectareController.text.length,
                            );
                          },
                        ),
                      ),
                      Text(
                        'Vazão por Hectare',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Vazão: ${_flowRate.toStringAsFixed(2)} L/min',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: canIncrement
                        ? () {
                            final newValue = options[currentIndex + 1];
                            setState(() {
                              _flowRatePerHectare = newValue;
                              _flowRatePerHectareController.text =
                                  newValue.toStringAsFixed(0);
                              _showResults = false;
                            });
                            _calculateFlowRate();
                          }
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: canIncrement
                          ? primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      Icons.add,
                      color: canIncrement ? primaryColor : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
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

  Widget _buildInfoChip(String text, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12, color: color != null ? Colors.white : primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color != null ? Colors.white : primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(TipModel tip) {
    final dropletSize = _dropletSizeMap[tip.dropletSizeId] ?? 'N/A';
    final isHighPressure = tip.pressure > 5.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TipDetailsPage(
                    tip: tip,
                    dropletSizeMap: _dropletSizeMap,
                    speed: _speed,
                    hasPWM: _hasPWM,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        tip.imageUrl ?? '',
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: primaryColor,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            Icons.agriculture_outlined,
                            size: 32,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
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
                                    '${tip.name} - ${tip.model}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                        if (isHighPressure)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 12,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Pressão alta',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _buildInfoChip(
                              '${tip.flowRate} L/min',
                              Icons.speed_rounded,
                            ),
                            _buildInfoChip(
                              '${tip.pressure} bar',
                              Icons.compress_rounded,
                            ),
                            _buildInfoChip(
                              '${tip.spacing.toStringAsFixed(1)} cm',
                              Icons.straighten_rounded,
                            ),
                            _buildInfoChip(
                              dropletSize,
                              Icons.water_drop_rounded,
                            ),
                            _buildInfoChip(
                              _hasPWM ? 'PWM' : 'Sem PWM',
                              Icons.flash_on_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          color: Colors.grey.shade200,
                          height: 1,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Clique para detalhes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    if (!_showResults) {
      return const SizedBox.shrink();
    }

    final filteredTips = _getFilteredTips();

    if (_recommendedTips.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma ponta encontrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tente ajustar os parâmetros da busca para obter resultados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.verified_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pontas Recomendadas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '${filteredTips.length} resultado${filteredTips.length > 1 ? 's' : ''} encontrado${filteredTips.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: _resetForm,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: primaryColor,
                  size: 20,
                ),
                tooltip: 'Nova busca',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pressure > 5.0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pressão acima de 5 bar. Considere trabalhar em pressões mais baixas para melhor eficiência.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildDropletSizeFilter(),
          const SizedBox(height: 20),
          ...filteredTips.map(_buildResultCard),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return _isLoading
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Buscando pontas...',
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Analisando os parâmetros para encontrar as melhores opções',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
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
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
            tooltip: 'Ver histórico',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Ajuda',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Configure todos os parâmetros para encontrar as pontas mais adequadas para sua aplicação. As buscas serão salvas automaticamente no histórico.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Entendi'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: CustomDrawer(
        currentRoute: '/tips',
        userName: _userName,
        userAvatarUrl: _userAvatarUrl,
        isLoadingUser: _isLoadingUser,
        onHomeTap: () {
          Navigator.pop(context);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        },
        onProfileTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        },
        onTipsTap: () {
          Navigator.pop(context);
        },
        onFavoritesTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FavoritesPage()),
          );
        },
        onCatalogTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CatalogPage()),
          );
        },
        onHistoryTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryPage()),
          );
        },
        onSettingsTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        },
        onLogoutTap: () => _showLogoutDialog(context),
      ),
      body: Container(
        color: backgroundColor,
        child: SafeArea(
          child: Form(
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader('Tipo de Aplicação',
                                      Icons.category_rounded,
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
                        ),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                                    'Modo de Ação',
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
                                      {
                                        'name': 'PWM',
                                        'icon': Icons.flash_on_rounded
                                      }
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
                        ),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _buildSectionHeader(
                                      'Parâmetros Técnicos', Icons.tune_rounded,
                                      subtitle:
                                          'Ajuste os valores usando os botões + e - ou digite manualmente'),
                                  _buildIncrementDecrementSelection(
                                    label: 'Pressão',
                                    currentValue: _pressure,
                                    unit: 'bar',
                                    icon: Icons.compress_rounded,
                                    options: _generatePressureValues(),
                                    onChanged: (newValue) => setState(() {
                                      _pressure = newValue;
                                    }),
                                    controller: _pressureController,
                                  ),
                                  _buildFlowRateSelection(),
                                  _buildIncrementDecrementSelection(
                                    label: 'Espaçamento',
                                    currentValue: _spacing,
                                    unit: 'cm',
                                    icon: Icons.straighten_rounded,
                                    options: _generateSpacingValues(),
                                    onChanged: (newValue) => setState(() {
                                      _spacing = newValue;
                                      _showResults = false;
                                      _calculateFlowRate();
                                    }),
                                    controller: _spacingController,
                                  ),
                                  _buildIncrementDecrementSelection(
                                    label: 'Velocidade',
                                    currentValue: _speed,
                                    unit: 'km/h',
                                    icon: Icons.speed_rounded,
                                    options: _generateSpeedValues(),
                                    onChanged: (newValue) => setState(() {
                                      _speed = newValue;
                                      _showResults = false;
                                      _calculateFlowRate();
                                    }),
                                    controller: _speedController,
                                  ),
                                ],
                              ),
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
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
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
                        elevation: 0,
                      ),
                      child: Text(
                        _isLoading ? 'BUSCANDO...' : 'BUSCAR PONTAS',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        final bool isActionMode = items.any((item) => item['name'] == 'PWM');

        if (isActionMode) {
          final nonPWMItems =
              items.where((item) => item['name'] != 'PWM').toList();
          final pwmItems =
              items.where((item) => item['name'] == 'PWM').toList();

          final hasPWM = pwmItems.isNotEmpty;
          final pwmItem = hasPWM ? pwmItems.first : null;

          final availableWidth = constraints.maxWidth;
          final totalSpacing = 12 * (nonPWMItems.length - 1);
          final buttonWidth =
              (availableWidth - totalSpacing) / nonPWMItems.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: nonPWMItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = item['name'] == selectedValue;

                    return Container(
                      width: buttonWidth,
                      margin: EdgeInsets.only(
                        right: index < nonPWMItems.length - 1 ? 12 : 0,
                      ),
                      child: _buildIconSelectionButton(
                        title: item['name'],
                        icon: item['icon'],
                        isSelected: isSelected,
                        onTap: () => onSelected(item['name']),
                        width: double.infinity,
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (hasPWM && pwmItem != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        'Tecnologia PWM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: _buildIconSelectionButton(
                            title: pwmItem['name'],
                            icon: pwmItem['icon'],
                            isSelected: isPWM,
                            onTap: () => onSelected(pwmItem['name']),
                            width: double.infinity,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          );
        } else {
          final availableWidth = constraints.maxWidth;
          final itemsPerRow = crossAxisCount;
          final totalSpacing = 12 * (itemsPerRow - 1);
          final buttonWidth = (availableWidth - totalSpacing) / itemsPerRow;

          final List<List<Map<String, dynamic>>> rows = [];
          for (int i = 0; i < items.length; i += itemsPerRow) {
            final end = (i + itemsPerRow) < items.length
                ? (i + itemsPerRow)
                : items.length;
            rows.add(items.sublist(i, end));
          }

          return Column(
            children: rows.map((rowItems) {
              final bool isLastRow = rows.last == rowItems;
              final bool hasSingleItem = rowItems.length == 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: isLastRow && hasSingleItem
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: rowItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = item['name'] == selectedValue;

                    return Container(
                      width: buttonWidth,
                      margin: EdgeInsets.only(
                        right: index < rowItems.length - 1 ? 12 : 0,
                      ),
                      child: _buildIconSelectionButton(
                        title: item['name'],
                        icon: item['icon'],
                        isSelected: isSelected,
                        onTap: () => onSelected(item['name']),
                        width: double.infinity,
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  List<TipModel> _getFilteredTips() {
    if (_selectedDropletSizes.isEmpty) {
      return _recommendedTips;
    }

    return _recommendedTips.where((tip) {
      return tip.dropletSizeId != null &&
          _selectedDropletSizes.contains(tip.dropletSizeId!);
    }).toList();
  }

  Widget _buildDropletSizeFilter() {
    if (_availableDropletSizes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Filtrar por Tamanho de Gota',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableDropletSizes.map((sizeId) {
                final isSelected = _selectedDropletSizes.contains(sizeId);
                final sizeName = _dropletSizeMap[sizeId] ?? 'N/A';

                final isOnlyOneSelected =
                    _selectedDropletSizes.length == 1 && isSelected;

                return ChoiceChip(
                  label: Text(sizeName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDropletSizes.add(sizeId);
                      } else {
                        if (!isOnlyOneSelected) {
                          _selectedDropletSizes.remove(sizeId);
                        }
                      }
                    });
                  },
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? primaryColor : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDropletSizes = _availableDropletSizes.toSet();
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                  ),
                  child: const Text('Selecionar Todos'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selectedDropletSizes.length > 1
                      ? () {
                          final firstSize = _selectedDropletSizes.first;
                          setState(() {
                            _selectedDropletSizes = {firstSize};
                          });
                        }
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Limpar'),
                ),
              ],
            ),
          ],
        ));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Tem certeza que deseja sair do aplicativo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _performLogout();
              },
              child: const Text(
                'Sair',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performLogout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sair: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
