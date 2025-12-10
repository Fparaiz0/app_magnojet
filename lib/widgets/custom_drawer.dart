import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomDrawer extends StatelessWidget {
  final String currentRoute;
  final String userName;
  final bool isLoadingUser;
  final VoidCallback? onHomeTap;
  final VoidCallback? onTipsTap;
  final VoidCallback? onCalculationsTap;
  final VoidCallback? onCatalogTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onFavoritesTap;

  const CustomDrawer({
    super.key,
    required this.currentRoute,
    required this.userName,
    required this.isLoadingUser,
    this.onHomeTap,
    this.onTipsTap,
    this.onCalculationsTap,
    this.onCatalogTap,
    this.onHistoryTap,
    this.onSettingsTap,
    this.onLogoutTap,
    this.onFavoritesTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    String displayUserName = userName.isNotEmpty ? userName : 'Usuário';
    String displayInitial = userName.isNotEmpty ? userName[0] : 'U';

    return Drawer(
      width: 280,
      child: Container(
        color: const Color(0xFF15325A),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 160,
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E3A8A),
                      Color(0xFF15325A),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.white24, width: 1),
                  ),
                ),
                child: isLoadingUser
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    displayInitial.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15325A),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayUserName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user?.email ?? 'sem_email@magnojet.com',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    color: Colors.white70, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Usuário ativo',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 20),
                  children: [
                    _buildSectionTitle('Principal'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.home_rounded,
                      title: 'Início',
                      isSelected: currentRoute == '/home',
                      onTap: onHomeTap,
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.search_rounded,
                      title: 'Selecionar Pontas',
                      isSelected: currentRoute == '/tips',
                      onTap: onTipsTap,
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.bookmark_rounded,
                      title: 'Favoritas',
                      isSelected: currentRoute == '/favorites',
                      onTap: onFavoritesTap,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Ferramentas'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.calculate_rounded,
                      title: 'Cálculos',
                      isSelected: currentRoute == '/calculations',
                      onTap: onCalculationsTap,
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.agriculture_rounded,
                      title: 'Catálogo',
                      isSelected: currentRoute == '/catalog',
                      onTap: onCatalogTap,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Outros'),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.history_rounded,
                      title: 'Histórico',
                      isSelected: currentRoute == '/history',
                      onTap: onHistoryTap,
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.settings_rounded,
                      title: 'Configurações',
                      isSelected: currentRoute == '/settings',
                      onTap: onSettingsTap,
                    ),
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.help_outline_rounded,
                      title: 'Ajuda',
                      isSelected: currentRoute == '/help',
                      onTap: null,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white24, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade700.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded,
                            color: Colors.redAccent, size: 22),
                        title: const Text(
                          'Sair da Conta',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        onTap: onLogoutTap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        dense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'MagnoJet v1.0.0',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '© 2024 Todos os direitos reservados',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : null,
        onTap: onTap ??
            () {
              Navigator.pop(context);

              if (title == 'Favoritas') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Página de favoritos não configurada'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        minLeadingWidth: 36,
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFF15325A)),
            SizedBox(width: 8),
            Text('Ajuda'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistema MagnoJet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Para suporte técnico ou dúvidas, entre em contato:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '📧 magnojet@magnojet.com.br\n📱 +55 (43) 3772-0025',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
