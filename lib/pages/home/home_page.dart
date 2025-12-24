import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';
import 'tip_selection_page.dart';
import '../../widgets/custom_drawer.dart';
import 'favorites_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'history_page.dart';
import 'catalog_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  String _userName = '';
  String? _userAvatarUrl;
  bool _isLoading = true;

  static const primaryColor = Color(0xFF15325A);
  static const backgroundColor = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
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
          _userAvatarUrl = response?['avatar_url'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar usuário: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saindo...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sair: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Tem certeza que deseja sair do aplicativo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDisabled
                  ? Colors.grey.shade200
                  : color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey.shade100
                      : color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isDisabled ? Colors.grey.shade400 : color,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? Colors.grey.shade400 : primaryColor,
                  ),
                ),
              ),
              if (isDisabled)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Em breve',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Carregando dados...',
            style: TextStyle(
              fontSize: 16,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo_branca.png',
              height: 40,
              width: 80,
            ),
            const SizedBox(width: 8),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog();
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      drawer: CustomDrawer(
        currentRoute: '/home',
        userName: _userName,
        userAvatarUrl: _userAvatarUrl,
        isLoadingUser: _isLoading,
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TipSelectionPage()),
          );
        },
        onFavoritesTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FavoritesPage()),
          );
        },
        onHistoryTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryPage()),
          );
        },
        onCatalogTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CatalogPage()),
          );
        },
        onSettingsTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        },
        onLogoutTap: () {
          Navigator.pop(context);
          _showLogoutDialog();
        },
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Container(
              color: backgroundColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  image: _userAvatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_userAvatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _userAvatarUrl == null
                                    ? Icon(
                                        Icons.person_rounded,
                                        color: primaryColor,
                                        size: 22,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bem-vindo(a),',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      _userName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.1)),
                            ),
                            child: const Text(
                              'Utilize o sistema para encontrar as pontas de pulverização mais adequadas para sua operação agrícola.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Funcionalidades',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      padding: EdgeInsets.zero,
                      children: [
                        _buildFeatureCard(
                          icon: Icons.search_rounded,
                          title: 'Selecionar Pontas',
                          color: primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TipSelectionPage(),
                              ),
                            );
                          },
                          isDisabled: false,
                        ),
                        _buildFeatureCard(
                          icon: Icons.bookmark_rounded,
                          title: 'Favoritas',
                          color: primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FavoritesPage(),
                              ),
                            );
                          },
                          isDisabled: false,
                        ),
                        _buildFeatureCard(
                          icon: Icons.history_rounded,
                          title: 'Histórico',
                          color: primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HistoryPage(),
                              ),
                            );
                          },
                          isDisabled: false,
                        ),
                        _buildFeatureCard(
                          icon: Icons.book_rounded,
                          title: 'Catálogos',
                          color: primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CatalogPage(),
                              ),
                            );
                          },
                          isDisabled: false,
                        ),
                        _buildFeatureCard(
                          icon: Icons.calculate_rounded,
                          title: 'Cálculos de Vazão',
                          color: primaryColor,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Funcionalidade em desenvolvimento'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          isDisabled: true,
                        ),
                        _buildFeatureCard(
                          icon: Icons.compare_arrows_rounded,
                          title: 'Comparar Pontas',
                          color: primaryColor,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Funcionalidade em desenvolvimento'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          isDisabled: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
