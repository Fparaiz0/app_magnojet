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
  });

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    String displayUserName =
        userName.isNotEmpty ? userName.toUpperCase() : 'USUÁRIO';
    String displayInitial =
        userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Drawer(
      width: 260,
      child: Container(
        color: const Color(0xFF15325A),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 115,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
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
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            child: Text(
                              displayInitial,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15325A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            user?.email ?? 'sem_email@magnojet.com',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 12),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.home_rounded,
                      title: 'Início',
                      isSelected: currentRoute == '/home',
                      onTap: onHomeTap ?? () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      icon: Icons.search_rounded,
                      title: 'Selecionar Pontas',
                      isSelected: currentRoute == '/tips',
                      onTap: onTipsTap ?? () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      icon: Icons.calculate_rounded,
                      title: 'Cálculos',
                      isSelected: currentRoute == '/calculations',
                      onTap: onCalculationsTap ?? () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      icon: Icons.agriculture_rounded,
                      title: 'Catálogo',
                      isSelected: currentRoute == '/catalog',
                      onTap: onCatalogTap ?? () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_rounded,
                      title: 'Histórico',
                      isSelected: currentRoute == '/history',
                      onTap: onHistoryTap ?? () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_rounded,
                      title: 'Configurações',
                      isSelected: currentRoute == '/settings',
                      onTap: onSettingsTap ?? () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white24, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout_rounded,
                          color: Colors.redAccent, size: 20),
                      title: const Text(
                        'Sair',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      onTap: onLogoutTap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      dense: true,
                    ),
                    const Text(
                      'MagnoJet v1.0.0',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        minLeadingWidth: 30,
      ),
    );
  }
}
