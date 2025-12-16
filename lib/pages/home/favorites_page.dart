import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/tip_selection_model.dart';
import '../../widgets/custom_drawer.dart';
import '../auth/login_page.dart';
import 'home_page.dart';
import 'tip_details_page.dart';
import 'tip_selection_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'history_page.dart';
import 'catalog_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final supabase = Supabase.instance.client;
  String _userName = '';
  String? _userAvatarUrl;
  bool _isLoadingUser = true;
  bool _isLoadingFavorites = true;
  List<TipModel> _favoriteTips = [];
  List<int> _favoriteIds = [];

  late TextEditingController _searchController;
  String _sortBy = 'recent';

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
  static const accentColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoadingUser = false);
      return;
    }

    try {
      final response = await supabase
          .from('users')
          .select('name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _userName = (response?['name'] ?? 'Usuário');
        _userAvatarUrl = (response?['avatar_url']);
        _isLoadingUser = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingUser = false);

      if (!e.toString().contains('404') &&
          !e.toString().contains('not found')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar usuário: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFavorites() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoadingFavorites = false);
      return;
    }

    if (mounted) {
      setState(() => _isLoadingFavorites = true);
    }

    try {
      final favoritesResponse = await supabase
          .from('favorites')
          .select('tip_id, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (favoritesResponse.isEmpty) {
        if (!mounted) return;
        setState(() {
          _favoriteTips = [];
          _favoriteIds = [];
          _isLoadingFavorites = false;
        });
        return;
      }

      final tipIds =
          favoritesResponse.map<int>((fav) => fav['tip_id'] as int).toList();

      final tipsResponse = await supabase.from('selecao').select('''
	            *,
	            pontas:pontas(id, ponta),
	            modelo:modelo(id, modelo),
	            pressao:pressao(id, bar),
	            vazao:vazao(id, litros),
	            espacamento:espacamento(id, cm),
	            tamanho_gota:tamanho_gota!inner(id, tamanho_gota),
	            modo_acao:modo_acao(modo_acao),
	            aplicacao:aplicacao(aplicacao)
	          ''').inFilter('id', tipIds).limit(100);

      final favoriteTips = tipsResponse
          .map<TipModel>((tip) => _convertSelecaoToTipModel(tip))
          .toList();

      favoriteTips.sort((a, b) {
        final indexA = tipIds.indexOf(a.id);
        final indexB = tipIds.indexOf(b.id);
        return indexA.compareTo(indexB);
      });

      if (!mounted) return;

      setState(() {
        _favoriteTips = favoriteTips;
        _favoriteIds = tipIds;
        _isLoadingFavorites = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFavorites = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar favoritos: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  TipModel _convertSelecaoToTipModel(Map<String, dynamic> selecaoData) {
    dynamic getFirstValue(String key, String field) {
      final data = selecaoData[key];

      if (data is List && data.isNotEmpty) {
        final firstItem = data[0];
        if (firstItem is Map<String, dynamic>) {
          return firstItem[field];
        }
        return null;
      }

      if (data is Map<String, dynamic>) {
        return data[field];
      }

      return null;
    }

    double localSafeParseDouble(dynamic value) {
      if (value == null) return 0.0;

      if (value is double) return value;

      if (value is int) return value.toDouble();

      if (value is String) {
        try {
          final cleanedValue = value.replaceAll(',', '.');

          final result = double.tryParse(cleanedValue);
          if (result != null) return result;

          final buffer = StringBuffer();
          for (final char in cleanedValue.runes) {
            final c = String.fromCharCode(char);
            if (c == '-' && buffer.isEmpty) {
              buffer.write(c);
            } else if (c == '.') {
              buffer.write(c);
            } else if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
              buffer.write(c);
            }
          }
          return double.tryParse(buffer.toString()) ?? 0.0;
        } catch (_) {
          return 0.0;
        }
      }

      return 0.0;
    }

    int localSafeParseInt(dynamic value) {
      if (value == null) return 0;

      if (value is int) return value;

      if (value is double) return value.toInt();

      if (value is String) {
        return int.tryParse(value) ?? 0;
      }

      return 0;
    }

    String localSafeParseString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    int? dropletSizeId;

    final tamanhoGotaRel = selecaoData['tamanho_gota'];

    if (tamanhoGotaRel is List && tamanhoGotaRel.isNotEmpty) {
      final firstItem = tamanhoGotaRel[0];
      dropletSizeId = localSafeParseInt(firstItem['id']);
    } else if (tamanhoGotaRel is Map) {
      dropletSizeId = localSafeParseInt(tamanhoGotaRel['id']);
    }

    if (dropletSizeId == null || dropletSizeId == 0) {
      dropletSizeId = localSafeParseInt(selecaoData['tamanho_gota_id']);
    }

    return TipModel(
      id: localSafeParseInt(selecaoData['id']),
      name: localSafeParseString(getFirstValue('pontas', 'ponta')),
      model: localSafeParseString(getFirstValue('modelo', 'modelo')),
      pressure: localSafeParseDouble(getFirstValue('pressao', 'bar')),
      flowRate: localSafeParseDouble(getFirstValue('vazao', 'litros')),
      spacing: localSafeParseDouble(getFirstValue('espacamento', 'cm')),
      speed: 12.0,
      imageUrl: localSafeParseString(selecaoData['image_url']),
      dropletSizeId: dropletSizeId,
      modoAcao: localSafeParseString(getFirstValue('modo_acao', 'modo_acao')),
      aplicacao: localSafeParseString(getFirstValue('aplicacao', 'aplicacao')),
    );
  }

  Future<void> _removeFavorite(int tipId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('tip_id', tipId);

      if (!mounted) return;

      setState(() {
        _favoriteTips.removeWhere((tip) => tip.id == tipId);
        _favoriteIds.remove(tipId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removido dos favoritos'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showRemoveDialog(TipModel tip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover dos favoritos?'),
        content: Text(
          'Tem certeza que deseja remover "${tip.name} - ${tip.model}" dos seus favoritos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFavorite(tip.id);
            },
            child: const Text(
              'Remover',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAllFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar todos os favoritos?'),
        content: const Text(
            'Esta ação removerá todas as pontas da sua lista de favoritos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Limpar tudo',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.from('favorites').delete().eq('user_id', user.id);

      if (!mounted) return;

      setState(() {
        _favoriteTips.clear();
        _favoriteIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os favoritos foram removidos'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao limpar favoritos: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _navigateToTipDetails(TipModel tip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TipDetailsPage(
          tip: tip,
          dropletSizeMap: _dropletSizeMap,
          speed: tip.speed,
          hasPWM: false,
        ),
      ),
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
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<TipModel> _getFilteredFavorites() {
    final searchQuery = _searchController.text.trim().toLowerCase();
    List<TipModel> filtered = List.from(_favoriteTips);

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((tip) {
        return tip.name.toLowerCase().contains(searchQuery) ||
            tip.model.toLowerCase().contains(searchQuery) ||
            tip.flowRate.toString().contains(searchQuery) ||
            tip.pressure.toString().contains(searchQuery);
      }).toList();
    }

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'flow':
        filtered.sort((a, b) => b.flowRate.compareTo(a.flowRate));
        break;
      case 'pressure':
        filtered.sort((a, b) => b.pressure.compareTo(a.pressure));
        break;
      case 'recent':
      default:
        break;
    }

    return filtered;
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                size: 80,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 20),
              Text(
                'Nenhuma ponta favoritada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Toque no ícone de favorito em qualquer ponta para adicioná-la aos seus favoritos',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TipSelectionPage()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text(
                  'Explorar Pontas',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadFavorites,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Recarregar'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(TipModel tip) {
    String getDropletSizeText(int? id) {
      if (id == null || id == 0) return 'N/A';
      return _dropletSizeMap[id] ?? 'ID: $id';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _navigateToTipDetails(tip),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: tip.imageUrl != null && tip.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          tip.imageUrl!,
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
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.agriculture_outlined,
                                  size: 32, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.agriculture_outlined,
                        size: 32, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tip.name} - ${tip.model}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSpecItem(
                          '${tip.flowRate.toStringAsFixed(1)} L/min',
                          Icons.speed_rounded,
                        ),
                        _buildSpecItem(
                          '${tip.pressure} bar',
                          Icons.compress_rounded,
                        ),
                        _buildSpecItem(
                          '${tip.spacing.toStringAsFixed(1)} cm',
                          Icons.straighten_rounded,
                        ),
                      ],
                    ),
                    if (tip.dropletSizeId != null && tip.dropletSizeId! > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.water_drop_rounded,
                                size: 14, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Tamanho da gota: ${getDropletSizeText(tip.dropletSizeId)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showRemoveDialog(tip),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bookmark_remove_rounded,
                    size: 20,
                    color: Colors.red,
                  ),
                ),
                tooltip: 'Remover dos favoritos',
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(String text, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 70),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Minhas Favoritas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_favoriteTips.length} ponta${_favoriteTips.length != 1 ? 's' : ''} favoritada${_favoriteTips.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (_favoriteTips.isNotEmpty)
                IconButton(
                  onPressed: _clearAllFavorites,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                  color: Colors.red,
                  tooltip: 'Limpar todos os favoritos',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nome, modelo, vazão...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        FocusScope.of(context).unfocus();
                      },
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Ordenar por:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip('Recentes', 'recent'),
                const SizedBox(width: 8),
                _buildSortChip('Nome', 'name'),
                const SizedBox(width: 8),
                _buildSortChip('Vazão', 'flow'),
                const SizedBox(width: 8),
                _buildSortChip('Pressão', 'pressure'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _sortBy = value);
        }
      },
      selectedColor: primaryColor,
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.shade300,
          width: isSelected ? 0 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFavorites = _getFilteredFavorites();
    final hasFavorites = _favoriteTips.isNotEmpty;
    final hasSearchResults = filteredFavorites.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Favoritas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      drawer: CustomDrawer(
        currentRoute: '/favorites',
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
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const TipSelectionPage()),
            (route) => false,
          );
        },
        onFavoritesTap: () {
          Navigator.pop(context);
          if (!ModalRoute.of(context)!.isCurrent) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesPage()),
              (route) => false,
            );
          }
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoadingFavorites
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Carregando seus favoritos...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : !hasFavorites
                      ? _buildEmptyState()
                      : !hasSearchResults
                          ? Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 60,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Nenhum resultado encontrado',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tente buscar por outros termos',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                          FocusScope.of(context).unfocus();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                        ),
                                        child: const Text('Limpar busca'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadFavorites,
                              color: primaryColor,
                              displacement: 40,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: filteredFavorites.length,
                                itemBuilder: (context, index) {
                                  final tip = filteredFavorites[index];
                                  return _buildFavoriteCard(tip);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: hasFavorites && hasSearchResults
          ? FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Funcionalidade de exportação em desenvolvimento'),
                    backgroundColor: primaryColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Compartilhar Lista'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              elevation: 4,
            )
          : null,
    );
  }
}
