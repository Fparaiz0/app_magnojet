import 'package:flutter/material.dart';

class TipSelectionPage extends StatefulWidget {
  const TipSelectionPage({super.key});

  @override
  State<TipSelectionPage> createState() => _TipSelectionPageState();
}

class _TipSelectionPageState extends State<TipSelectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Valores iniciais
  double _pressure = 3.0;
  double _flowRate = 0.8;

  // Seleções
  String? _selectedApplicationType = 'Aplicação em Solo';
  String? _selectedApplication = 'Herbicida';
  String? _selectedActionMode = 'Sistemico';
  bool _hasPWM = false;

  bool _showResults = false;
  bool _isLoading = false;

  // Constantes
  static const primaryColor = Color(0xFF15325A);
  static const secondaryColor = Color(0xFFE8F0F8);
  static const accentColor = Color(0xFF4CAF50);

  // Dados
  final List<Map<String, dynamic>> _applicationTypes = [
    {'name': 'Florestal', 'icon': Icons.forest_rounded},
    {'name': 'Aplicação Seletiva', 'icon': Icons.tune_rounded},
    {'name': 'Área Total', 'icon': Icons.grass_rounded},
    {'name': 'Barra Curta', 'icon': Icons.auto_awesome_motion_rounded},
    {'name': 'Conforto Termico', 'icon': Icons.thermostat_rounded},
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
    {'name': 'Ambos', 'icon': Icons.linear_scale_rounded},
    {'name': 'Não se aplica', 'icon': Icons.cancel_rounded},
  ];

  // Métodos
  Future<void> _searchTips() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _showResults = false;
    });

    // Simula busca assíncrona
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _showResults = true;
    });

    // Scroll para resultados
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pontas encontradas com sucesso!'),
        backgroundColor: accentColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _pressure = 3.0;
      _flowRate = 0.8;
      _selectedApplicationType = 'Aplicação em Solo';
      _selectedApplication = 'Herbicida';
      _selectedActionMode = 'Sistemico';
      _hasPWM = false;
      _showResults = false;
    });
  }

  Widget _buildIconSelectionButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    double? width,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? primaryColor.withOpacity(0.8)
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

  Widget _buildNumericControl({
    required String label,
    required double value,
    required String unit,
    required IconData icon,
    required double step,
    required ValueChanged<double> onChanged,
    double minValue = 0.0,
    double? maxValue,
  }) {
    final valueString = value.toStringAsFixed(step < 1 ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 22),
              const SizedBox(width: 8),
              Text(
                '$label ($unit)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.remove, color: primaryColor),
                  onPressed:
                      value > minValue ? () => onChanged(value - step) : null,
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    border: Border.all(
                        color: primaryColor.withOpacity(0.3), width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    valueString,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: primaryColor),
                  onPressed: maxValue != null && value >= maxValue
                      ? null
                      : () => onChanged(value + step),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Divider(color: Colors.black12, height: 1),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    if (!_showResults) return const SizedBox.shrink();

    final recommendedTips = [
      {
        'name': 'Jato Plano AI80 - 03',
        'color': 'Azul',
        'flowRate': (_flowRate * 0.95).toStringAsFixed(1),
        'pressure': _pressure.toStringAsFixed(1),
        'efficiency': '95%',
        'detail': 'Excelente para herbicidas sistêmicos',
      },
      {
        'name': 'Cone Cheio CV98 - 04',
        'color': 'Amarelo',
        'flowRate': (_flowRate * 1.06).toStringAsFixed(1),
        'pressure': (_pressure * 0.9).toStringAsFixed(1),
        'efficiency': '92%',
        'detail': 'Ideal para aplicação em solo com baixa deriva',
      },
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Pontas Recomendadas', Icons.verified_rounded,
              subtitle: 'Baseado nos parâmetros informados'),
          ...recommendedTips.map((tip) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: tip['color'] == 'Azul'
                        ? Colors.blue.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: tip['color'] == 'Azul'
                          ? Colors.blue.shade200
                          : Colors.amber.shade200,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.air_rounded,
                    color: tip['color'] == 'Azul'
                        ? Colors.blue.shade700
                        : Colors.amber.shade700,
                    size: 24,
                  ),
                ),
                title: Text(
                  tip['name']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(tip['detail']!),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(
                            '${tip['flowRate']} L/min', Icons.speed_rounded),
                        _buildInfoChip(
                            '${tip['pressure']} bar', Icons.compress_rounded),
                        _buildInfoChip(tip['efficiency']!, Icons.star_rounded),
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.grey),
                onTap: () {
                  // Navegar para detalhes da ponta
                },
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nova Busca'),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
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
                  'Buscando pontas...',
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
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 16.0 * 2;
    final cardPadding = 20.0 * 2;
    final availableWidth = screenWidth - padding - cardPadding;

    // Larguras calculadas
    final buttonWidth3Col = (availableWidth - (12 * 2)) / 3;

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
                    'Preencha todos os campos para encontrar as pontas mais adequadas para sua aplicação.',
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
                    // Tipo de Aplicação
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
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _applicationTypes.map((appType) {
                                return SizedBox(
                                  width: buttonWidth3Col,
                                  child: _buildIconSelectionButton(
                                    title: appType['name'],
                                    icon: appType['icon'],
                                    isSelected: _selectedApplicationType ==
                                        appType['name'],
                                    onTap: () {
                                      setState(() {
                                        _selectedApplicationType =
                                            appType['name'];
                                      });
                                    },
                                    width: buttonWidth3Col,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Aplicação, Modo de Ação e PWM
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
                            _buildSectionHeader('Configurações da Aplicação',
                                Icons.filter_alt_rounded,
                                subtitle:
                                    'Configure os parâmetros da aplicação'),

                            // Seção de Aplicação
                            const Text(
                              'Tipo de Aplicação',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _applications.map((app) {
                                return SizedBox(
                                  width: (availableWidth - (8 * 2)) / 3,
                                  child: _buildIconSelectionButton(
                                    title: app['name'],
                                    icon: app['icon'],
                                    isSelected:
                                        _selectedApplication == app['name'],
                                    onTap: () {
                                      setState(() {
                                        _selectedApplication = app['name'];
                                      });
                                    },
                                    width: (availableWidth - (8 * 2)) / 3,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // MODIFICAÇÃO: Modo de Ação e PWM na mesma linha - sem texto "Ativo/Inativo"
                            const Text(
                              'Modo de Ação & PWM',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Modos de Ação - 3 botões
                                ..._actionModes.map((mode) {
                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: _buildIconSelectionButton(
                                        title: mode['name'],
                                        icon: mode['icon'],
                                        isSelected:
                                            _selectedActionMode == mode['name'],
                                        onTap: () {
                                          setState(() {
                                            _selectedActionMode = mode['name'];
                                          });
                                        },
                                        width: null,
                                      ),
                                    ),
                                  );
                                }).toList(),

                                // MODIFICAÇÃO: PWM como botão simples sem subtítulo
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    child: _buildIconSelectionButton(
                                      title: 'PWM',
                                      icon: Icons.flash_on_rounded,
                                      isSelected: _hasPWM,
                                      onTap: () {
                                        setState(() {
                                          _hasPWM = !_hasPWM;
                                        });
                                      },
                                      width: null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Parâmetros Numéricos
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
                                subtitle: 'Ajuste os parâmetros da aplicação'),
                            _buildNumericControl(
                              label: 'Pressão',
                              value: _pressure,
                              unit: 'bar',
                              icon: Icons.compress_rounded,
                              step: 0.1,
                              minValue: 0.1,
                              maxValue: 10.0,
                              onChanged: (newValue) =>
                                  setState(() => _pressure = newValue),
                            ),
                            _buildNumericControl(
                              label: 'Vazão',
                              value: _flowRate,
                              unit: 'L/min',
                              icon: Icons.opacity_rounded,
                              step: 0.1,
                              minValue: 0.1,
                              maxValue: 5.0,
                              onChanged: (newValue) =>
                                  setState(() => _flowRate = newValue),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Loading Indicator
                    _buildLoadingIndicator(),

                    // Resultados
                    _buildResultSection(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Botão de Busca
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchTips,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.search_rounded, color: Colors.white),
                    label: Text(
                      _isLoading ? 'Buscando...' : 'Buscar Pontas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLoading ? Colors.grey : primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
