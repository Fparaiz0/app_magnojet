import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../models/tip_selection_model.dart';
import '../../../services/tip_selection_service.dart';
import 'home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_drawer.dart';
import '../auth/login_page.dart';

class TipSelectionPage extends StatefulWidget {
  const TipSelectionPage({super.key});

  @override
  State<TipSelectionPage> createState() => _TipSelectionPageState();
}

class _TipSelectionPageState extends State<TipSelectionPage> {
  final TipService _tipService = TipService();
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  String _userName = '';
  bool _isLoadingUser = true;
  double _pressure = 3.0;
  double _flowRate = 0.8;
  double _spacing = 35.0;
  double _speed = 5.0;

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

  List<double> _generatePressureValues() {
    final values = <double>[];
    for (double i = 1.0; i <= 10.0; i += 0.1) {
      values.add(double.parse(i.toStringAsFixed(1)));
    }
    return values;
  }

  List<double> _generateFlowRateValues() {
    final values = <double>[];
    for (double i = 0.5; i <= 10.0; i += 0.5) {
      values.add(i);
    }
    return values;
  }

  List<double> _generateSpacingValues() {
    final values = <double>[];
    for (double i = 20.0; i <= 100.0; i += 0.5) {
      values.add(i);
    }
    return values;
  }

  List<double> _generateSpeedValues() {
    final values = <double>[];
    for (double i = 1.0; i <= 20.0; i += 0.5) {
      values.add(i);
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _imageCache.clear();
    super.dispose();
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
          .select('name')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userName = (response?['name'] ?? 'Usuário').split(' ').first;
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
        speedValue: _speed,
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
      _pressure = 3.0;
      _flowRate = 0.8;
      _spacing = 35.0;
      _speed = 5.0;
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

  Widget _buildIncrementDecrementSelection({
    required String label,
    required double currentValue,
    required String unit,
    required IconData icon,
    required List<double> options,
    required ValueChanged<double> onChanged,
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
                  Text(
                    _formatExactValue(currentValue, unit),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
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
                  color: primaryColor,
                ),
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
                                  _formatExactValue(tip.speed, 'km/h'),
                                  Icons.speed_rounded,
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
                    'Preencha todos os campos para encontrar as pontas mais adequadas para sua aplicação. Use os botões + e - para ajustar os valores.',
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
      drawer: CustomDrawer(
        currentRoute: '/tips',
        userName: _userName,
        isLoadingUser: _isLoadingUser,
        onHomeTap: () {
          Navigator.pop(context);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        },
        onTipsTap: () => Navigator.pop(context),
        onLogoutTap: () => _showLogoutDialog(context),
      ),
      body: SafeArea(
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
                                      'Ajuste os valores usando os botões + e -'),
                              _buildIncrementDecrementSelection(
                                label: 'Pressão',
                                currentValue: _pressure,
                                unit: 'bar',
                                icon: Icons.compress_rounded,
                                options: _generatePressureValues(),
                                onChanged: (newValue) => setState(() {
                                  _pressure = newValue;
                                }),
                              ),
                              _buildIncrementDecrementSelection(
                                label: 'Vazão',
                                currentValue: _flowRate,
                                unit: 'L/min',
                                icon: Icons.opacity_rounded,
                                options: _generateFlowRateValues(),
                                onChanged: (newValue) => setState(() {
                                  _flowRate = newValue;
                                }),
                              ),
                              _buildIncrementDecrementSelection(
                                label: 'Espaçamento',
                                currentValue: _spacing,
                                unit: 'cm',
                                icon: Icons.straighten_rounded,
                                options: _generateSpacingValues(),
                                onChanged: (newValue) => setState(() {
                                  _spacing = newValue;
                                }),
                              ),
                              _buildIncrementDecrementSelection(
                                label: 'Velocidade',
                                currentValue: _speed,
                                unit: 'km/h',
                                icon: Icons.speed_rounded,
                                options: _generateSpeedValues(),
                                onChanged: (newValue) => setState(() {
                                  _speed = newValue;
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
          final itemsPerRow = 3;
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
