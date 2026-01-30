import 'package:flutter/material.dart';
import 'package:magnojet/pages/auth/login_page.dart';
import 'package:magnojet/pages/home/catalog_page.dart';
import 'package:magnojet/pages/home/favorites_page.dart';
import 'package:magnojet/pages/home/history_page.dart';
import 'package:magnojet/pages/home/home_page.dart';
import 'package:magnojet/pages/home/profile_page.dart';
import 'package:magnojet/pages/home/tip_selection_page.dart';
import 'package:magnojet/services/notification_permission_service.dart';
import 'package:magnojet/widgets/custom_drawer.dart';
import 'package:magnojet/widgets/notification_settings_tile.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  String _userName = '';
  String _userEmail = '';
  String? _userAvatarUrl;
  bool _isLoadingUser = true;
  bool _darkModeEnabled = false;
  bool _autoSyncEnabled = true;
  String _selectedLanguage = 'Português';
  String _selectedUnitSystem = 'Métrico';
  String _selectedTheme = 'Claro';

  late final NotificationPermissionService _permissionService;

  static const primaryColor = Color(0xFF15325A);
  static const backgroundColor = Color(0xFFF5F7FA);
  final int currentYear = DateTime.now().year;

  final List<String> _languages = [
    'Português',
    'English',
    'Español',
  ];

  final List<String> _unitSystems = [
    'Métrico',
    'Imperial',
  ];

  final List<String> _themes = [
    'Claro',
    'Escuro',
    'Automático',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
    _permissionService = NotificationPermissionService();
    _permissionService.initialize().then((_) {
      _loadNotificationSettings();
    });
  }

  Future<void> _loadNotificationSettings() async {
    try {
      await _permissionService.getNotificationSettings();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações de notificação: $e');
    }
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
          .select('name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userName = response?['name'] ?? 'Usuário';
          _userEmail = response?['email'] ?? user.email ?? 'Não informado';
          _userAvatarUrl = response?['avatar_url'];
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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
        _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
        _selectedLanguage = prefs.getString('selected_language') ?? 'Português';
        _selectedUnitSystem =
            prefs.getString('selected_unit_system') ?? 'Métrico';
        _selectedTheme = prefs.getString('selected_theme') ?? 'Claro';
      });
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
      await prefs.setBool('auto_sync_enabled', _autoSyncEnabled);
      await prefs.setString('selected_language', _selectedLanguage);
      await prefs.setString('selected_unit_system', _selectedUnitSystem);
      await prefs.setString('selected_theme', _selectedTheme);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar configurações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Widget _buildUserInfoCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                image: _userAvatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_userAvatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _userAvatarUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 30,
                      color: primaryColor,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text(
                        'Ver perfil completo',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          const Row(
            children: [
              Icon(Icons.notifications_rounded, color: primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Notificações',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15325A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          NotificationSettingsTile(
            activeColor: primaryColor,
            inactiveColor: Colors.grey[400]!,
            onToggleChanged: (enabled) {
              setState(() {});
              _saveNotificationPreference(enabled);
            },
          ),
          const Divider(height: 24, color: Colors.grey),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sync_rounded,
                      size: 20, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sincronização automática',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sincronize dados automaticamente',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoSyncEnabled,
                  onChanged: (value) {
                    setState(() {
                      _autoSyncEnabled = value;
                    });
                  },
                  activeThumbColor: primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNotificationPreference(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (e) {
      debugPrint('Erro ao salvar preferência de notificação: $e');
    }
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15325A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  onChanged: onChanged,
                  items: options.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  icon: Icon(Icons.arrow_drop_down_rounded,
                      color: Colors.grey.shade600),
                  elevation: 2,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLogout ? color.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLogout ? color : Colors.grey.shade300,
                width: isLogout ? 1 : 0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isLogout ? color : primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isLogout ? color : Colors.black87,
                    ),
                  ),
                ),
                if (!isLogout)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Configurações',
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
            icon: const Icon(Icons.save_rounded),
            onPressed: _saveSettings,
            tooltip: 'Salvar configurações',
          ),
        ],
      ),
      drawer: CustomDrawer(
        currentRoute: '/settings',
        userName: _userName,
        isLoadingUser: _isLoadingUser,
        userAvatarUrl: _userAvatarUrl,
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
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const TipSelectionPage()),
            (route) => false,
          );
        },
        onFavoritesTap: () {
          Navigator.pop(context);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const FavoritesPage()),
            (route) => false,
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
        },
        onLogoutTap: () => _showLogoutDialog(context),
      ),
      body: Container(
        color: backgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserInfoCard(),
                _buildNotificationSection(),
                _buildSettingsSection(
                  title: 'Preferências',
                  icon: Icons.settings_rounded,
                  children: [
                    _buildDropdownSetting(
                      title: 'Idioma',
                      subtitle: 'Selecione o idioma do aplicativo',
                      value: _selectedLanguage,
                      options: _languages,
                      icon: Icons.language_rounded,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLanguage = value;
                          });
                        }
                      },
                    ),
                    _buildDropdownSetting(
                      title: 'Sistema de Unidades',
                      subtitle: 'Selecione o sistema de medição',
                      value: _selectedUnitSystem,
                      options: _unitSystems,
                      icon: Icons.straighten_rounded,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUnitSystem = value;
                          });
                        }
                      },
                    ),
                    _buildDropdownSetting(
                      title: 'Tema',
                      subtitle: 'Selecione o tema do aplicativo',
                      value: _selectedTheme,
                      options: _themes,
                      icon: Icons.palette_rounded,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedTheme = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                _buildSettingsSection(
                  title: 'Ações',
                  icon: Icons.touch_app_rounded,
                  children: [
                    _buildActionButton(
                      title: 'Limpar cache',
                      icon: Icons.delete_sweep_rounded,
                      color: Colors.orange,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Limpar Cache'),
                            content: const Text(
                              'Tem certeza que deseja limpar o cache do aplicativo?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);

                                  try {
                                    final tempDir =
                                        await getTemporaryDirectory();
                                    if (await tempDir.exists()) {
                                      await tempDir.delete(recursive: true);
                                    }

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Cache limpo com sucesso!'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Erro ao limpar cache: $e'),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Limpar'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      title: 'Sobre o aplicativo',
                      icon: Icons.info_rounded,
                      color: Colors.green,
                      onPressed: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'MagnoJet',
                          applicationVersion: '1.0.0',
                          applicationLegalese:
                              '© $currentYear Todos os direitos reservados',
                          children: [
                            const SizedBox(height: 16),
                            const Text(
                              'Aplicativo para seleção de pontas de pulverização agrícola.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                    _buildActionButton(
                      title: 'Sair da conta',
                      icon: Icons.logout_rounded,
                      color: Colors.red,
                      onPressed: () => _showLogoutDialog(context),
                      isLogout: true,
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Algumas configurações podem exigir reinício do aplicativo para serem aplicadas.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSettings,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save_rounded),
        label: const Text('Salvar'),
        elevation: 2,
      ),
    );
  }
}
