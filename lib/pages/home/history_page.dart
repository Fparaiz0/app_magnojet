import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/search_history_service.dart';
import '../../models/search_history_model.dart';
import '../../widgets/custom_drawer.dart';
import '../auth/login_page.dart';
import '../home/home_page.dart';
import 'tip_selection_page.dart';
import 'favorites_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'search_history_detail_page.dart';
import 'catalog_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final supabase = Supabase.instance.client;
  final SearchHistoryService _historyService = SearchHistoryService();

  String _userName = '';
  String? _userAvatarUrl;
  bool _isLoadingUser = true;
  bool _isLoadingHistory = true;
  List<SearchHistoryModel> _searchHistory = [];

  static const Color primaryColor = Color(0xFF15325A);
  static const Color backgroundColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSearchHistory();
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
          _userName = response?['name'] ?? 'Usuário';
          _userAvatarUrl = response?['avatar_url'];
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _loadSearchHistory() async {
    if (mounted) {
      setState(() => _isLoadingHistory = true);
    }

    try {
      final history = await _historyService.getUserSearchHistory();

      if (mounted) {
        setState(() {
          _searchHistory = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        _showErrorSnackbar('Erro ao carregar histórico');
      }
    }
  }

  Future<void> _refreshHistory() async {
    await _loadSearchHistory();
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Limpar Histórico',
          style: TextStyle(color: textPrimary),
        ),
        content: Text(
          'Tem certeza que deseja limpar todo o histórico de buscas?',
          style: TextStyle(color: textSecondary),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllHistory();
            },
            child: const Text(
              'Limpar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllHistory() async {
    try {
      await _historyService.clearAllSearchHistory();
      if (mounted) {
        setState(() {
          _searchHistory.clear();
        });
        _showSuccessSnackbar('Histórico limpo com sucesso!');
      }
    } catch (e) {
      _showErrorSnackbar('Erro ao limpar histórico');
    }
  }

  Future<void> _deleteWithConfirmation(int id) async {
    final confirmed = await _showDeleteConfirmationDialog(id);
    if (confirmed) {
      await _performDeleteItem(id);
    }
  }

  Future<void> _performDeleteItem(int id) async {
    try {
      await _historyService.deleteSearchHistory(id);
      if (mounted) {
        setState(() {
          _searchHistory.removeWhere((item) => item.id == id);
        });
        _showSuccessSnackbar('Busca excluída com sucesso!');
      }
    } catch (e) {
      _showErrorSnackbar('Erro ao excluir busca');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(SearchHistoryModel history, int index) {
    final parameters = _parseParameters(history.parametersJson);
    final hasResults = history.resultCount != null && history.resultCount! > 0;

    return Container(
      margin: EdgeInsets.fromLTRB(16, index == 0 ? 16 : 8, 16, 8),
      child: Dismissible(
        key: Key('history_${history.id}_$index'),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(
            Icons.delete_forever_rounded,
            color: Colors.red,
          ),
        ),
        confirmDismiss: (direction) async {
          final confirmed = await _showDeleteConfirmationDialog(history.id);
          return confirmed;
        },
        onDismissed: (_) async {
          await _performDeleteItem(history.id);
        },
        child: Card(
          color: cardColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchHistoryDetailPage(
                    history: history,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: hasResults
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasResults
                          ? Icons.check_circle_rounded
                          : Icons.history_rounded,
                      color: hasResults ? Colors.green : Colors.grey.shade600,
                      size: 24,
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
                              child: Text(
                                _formatSearchDate(history.searchDate),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasResults
                              ? '${history.resultCount} pontas encontradas'
                              : 'Nenhuma ponta encontrada',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasResults
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (parameters.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (parameters['application_type'] != null)
                                _buildParameterChip(
                                  parameters['application_type']!,
                                  hasResults ? Colors.green : primaryColor,
                                ),
                              if (parameters['pressure'] != null)
                                _buildParameterChip(
                                  '${parameters['pressure']} bar',
                                  hasResults ? Colors.green : primaryColor,
                                ),
                              if (parameters['flow_rate'] != null)
                                _buildParameterChip(
                                  '${parameters['flow_rate']} L/min',
                                  hasResults ? Colors.green : primaryColor,
                                ),
                              if (parameters['spacing'] != null)
                                _buildParameterChip(
                                  '${parameters['spacing']} cm',
                                  hasResults ? Colors.green : primaryColor,
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Clique para ver detalhes',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  _deleteWithConfirmation(history.id),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Excluir busca',
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

  Future<bool> _showDeleteConfirmationDialog(int id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Excluir Busca',
          style: TextStyle(color: textPrimary),
        ),
        content: Text(
          'Tem certeza que deseja excluir esta busca do histórico?',
          style: TextStyle(color: textSecondary),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildParameterChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Map<String, String> _parseParameters(String jsonString) {
    final params = <String, String>{};
    try {
      final cleaned = jsonString.trim();
      final pairs = cleaned.split(', ');
      for (final pair in pairs) {
        final keyValue = pair.split(': ');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            params[key] = value;
          }
        }
      }
    } catch (_) {}
    return params;
  }

  String _formatSearchDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return 'Hoje • $time';
    } else if (difference.inDays == 1) {
      return 'Ontem • $time';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dias atrás • $time';
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month/${date.year} • $time';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma busca realizada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Suas buscas de pontas aparecerão aqui',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TipSelectionPage(),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.search_rounded, color: Colors.white),
              label: const Text(
                'FAZER UMA BUSCA',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: index == 4 ? 0 : 12),
          child: Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 60,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
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
        );
      },
    );
  }

  Widget _buildHistoryList() {
    if (_searchHistory.isEmpty && !_isLoadingHistory) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      backgroundColor: Colors.white,
      color: primaryColor,
      onRefresh: _refreshHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(0),
        itemCount: _searchHistory.length,
        itemBuilder: (context, index) {
          return _buildHistoryItem(_searchHistory[index], index);
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Confirmar Saída',
            style: TextStyle(color: textPrimary),
          ),
          content: Text(
            'Tem certeza que deseja sair do aplicativo?',
            style: TextStyle(color: textSecondary),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(color: textSecondary),
              ),
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

  Future<void> _performLogout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Erro ao sair da conta');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Histórico de Buscas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_searchHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _showClearHistoryDialog,
              tooltip: 'Limpar histórico',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshHistory,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      drawer: CustomDrawer(
        currentRoute: '/history',
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
      body: SafeArea(
        child: _isLoadingHistory && _searchHistory.isEmpty
            ? _buildLoadingShimmer()
            : _buildHistoryList(),
      ),
    );
  }
}
