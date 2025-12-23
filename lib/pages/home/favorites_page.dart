import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
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

  Future<String> _imageToBase64(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final base64 = base64Encode(bytes);
        final mimeType = _getMimeType(imageUrl);
        return 'data:$mimeType;base64,$base64';
      }
    } catch (_) {}
    return '';
  }

  String _getMimeType(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lowerUrl.endsWith('.gif')) {
      return 'image/gif';
    }

    if (lowerUrl.endsWith('.svg')) {
      return 'image/svg+xml';
    }

    return 'image/jpeg';
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

  Future<void> _shareFavoritesList() async {
    final filteredFavorites = _getFilteredFavorites();
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final formattedDateTime =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (filteredFavorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há favoritos para compartilhar'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 16),
              Text('Gerando lista para compartilhamento...'),
            ],
          ),
        ),
      );

      final StringBuffer htmlContent = StringBuffer();

      htmlContent.write('''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lista de Pontas Favoritas - Magnojet</title>
 <style>
    :root {
        --primary-color: #15325A;
        --secondary-color: #4CAF50;
        --accent-color: #1565c0;
        --success-color: #2e7d32;
        --info-color: #0288d1;
        --warning-color: #f57c00;
        --light-blue: #e3f2fd;
        --light-green: #e8f5e9;
        --light-orange: #fff3e0;
        --light-gray: #f5f5f5;
        --medium-gray: #e0e0e0;
        --dark-gray: #616161;
        --text-color: #263238;
        --border-radius: 12px;
        --box-shadow: 0 6px 20px rgba(0, 0, 0, 0.1);
        --box-shadow-hover: 0 12px 28px rgba(0, 0, 0, 0.15);
        --transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    }

    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: 'Inter', 'Segoe UI', 'Roboto', system-ui, sans-serif;
        line-height: 1.7;
        color: var(--text-color);
        background: linear-gradient(135deg, #fafafa 0%, #f0f2f5 100%);
        min-height: 100vh;
        padding: 25px;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
    }

    .container {
        max-width: 1000px;
        margin: 0 auto;
        background: white;
        border-radius: var(--border-radius);
        box-shadow: var(--box-shadow);
        overflow: hidden;
        border: 1px solid rgba(0, 0, 0, 0.08);
        position: relative;
    }

    .header {
        background: linear-gradient(135deg, var(--primary-color) 0%, #0d1f3d 100%);
        color: white;
        padding: 40px 30px;
        text-align: center;
        position: relative;
        overflow: hidden;
    }

    .header::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 5px;
        background: linear-gradient(90deg, var(--secondary-color), #66bb6a, var(--accent-color));
        background-size: 300% 100%;
        animation: gradient-shift 3s ease infinite;
    }

    .header::after {
        content: "";
        position: absolute;
        top: 0;
        right: 0;
        width: 150px;
        height: 150px;
        background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0) 70%);
    }

    .title {
        font-size: 32px;
        font-weight: 800;
        margin-bottom: 12px;
        letter-spacing: -0.5px;
        position: relative;
        z-index: 1;
        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
    }

    .subtitle {
        font-size: 16px;
        opacity: 0.9;
        font-weight: 400;
        letter-spacing: 0.3px;
        position: relative;
        z-index: 1;
    }

    .user-info {
        background: linear-gradient(135deg, var(--light-blue) 0%, #bbdefb 100%);
        margin: 30px;
        padding: 25px;
        border-radius: var(--border-radius);
        border: 2px solid rgba(21, 101, 192, 0.2);
        display: flex;
        align-items: center;
        gap: 25px;
        box-shadow: 0 4px 12px rgba(21, 101, 192, 0.1);
        transition: var(--transition);
    }

    .user-info:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 20px rgba(21, 101, 192, 0.15);
        border-color: rgba(21, 101, 192, 0.3);
    }

    .user-avatar {
        width: 80px;
        height: 80px;
        border-radius: 50%;
        object-fit: cover;
        border: 4px solid white;
        box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
        transition: var(--transition);
    }

    .user-avatar:hover {
        transform: scale(1.05) rotate(5deg);
    }

    .avatar-fallback {
        width: 80px;
        height: 80px;
        border-radius: 50%;
        background: linear-gradient(135deg, var(--accent-color) 0%, #0d47a1 100%);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 32px;
        border: 4px solid white;
        box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
        font-weight: bold;
        transition: var(--transition);
    }

    .avatar-fallback:hover {
        transform: scale(1.05);
        background: linear-gradient(135deg, #0d47a1 0%, var(--accent-color) 100%);
    }

    .user-details {
        flex: 1;
    }

    .user-name {
        font-size: 20px;
        font-weight: 700;
        color: var(--primary-color);
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        gap: 8px;
    }

    .user-name::before {
        content: "👤";
        font-size: 18px;
    }

    .user-date {
        font-size: 15px;
        color: var(--dark-gray);
        display: flex;
        align-items: center;
        gap: 8px;
    }

    .user-date::before {
        content: "📅";
        font-size: 14px;
    }

    .summary {
        background: linear-gradient(135deg, var(--light-green) 0%, #a5d6a7 100%);
        margin: 0 30px 30px;
        padding: 25px;
        border-radius: var(--border-radius);
        text-align: center;
        border: 2px solid rgba(46, 125, 50, 0.2);
        box-shadow: 0 4px 12px rgba(46, 125, 50, 0.1);
        position: relative;
        overflow: hidden;
    }

    .summary h2 {
        color: var(--success-color);
        font-size: 22px;
        font-weight: 700;
        margin-bottom: 10px;
    }

    .summary p {
        color: var(--success-color);
        font-size: 16px;
        font-weight: 600;
    }

    .summary strong {
        background: white;
        padding: 4px 12px;
        border-radius: 20px;
        margin: 0 5px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }

    .tip-card {
        background: white;
        margin: 30px;
        border-radius: var(--border-radius);
        overflow: hidden;
        border: 2px solid var(--medium-gray);
        transition: var(--transition);
        position: relative;
        background: linear-gradient(to bottom, white 0%, #fafafa 100%);
    }

    .tip-card:hover {
        transform: translateY(-5px);
        box-shadow: var(--box-shadow-hover);
        border-color: var(--accent-color);
    }

    .tip-number {
        position: absolute;
        top: 20px;
        right: 20px;
        background: linear-gradient(135deg, var(--primary-color) 0%, #0d1f3d 100%);
        color: white;
        width: 42px;
        height: 42px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: bold;
        font-size: 18px;
        z-index: 2;
        box-shadow: 0 4px 12px rgba(21, 50, 90, 0.4);
        border: 2px solid white;
    }

    .tip-content {
        padding: 30px;
    }

    .tip-header {
        display: flex;
        align-items: flex-start;
        gap: 30px;
        margin-bottom: 25px;
        position: relative;
    }

    @media (max-width: 768px) {
        .tip-header {
            flex-direction: column;
            gap: 25px;
        }
        
        .user-info {
            margin: 20px;
            flex-direction: column;
            text-align: center;
            gap: 20px;
        }
        
        .summary {
            margin: 0 20px 20px;
        }
        
        .tip-card {
            margin: 20px;
        }
    }

    .tip-image-container {
        flex-shrink: 0;
        width: 200px;
        height: 200px;
        position: relative;
    }

    .tip-image {
        width: 100%;
        height: 100%;
        object-fit: contain;
        border: 2px solid var(--medium-gray);
        border-radius: 10px;
        background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
        padding: 15px;
        transition: var(--transition);
        position: relative;
        z-index: 1;
    }

    .tip-image:hover {
        border-color: var(--accent-color);
        transform: scale(1.03);
        box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
    }

    .tip-image::after {
        content: "";
        position: absolute;
        top: -5px;
        left: -5px;
        right: -5px;
        bottom: -5px;
        background: linear-gradient(135deg, var(--accent-color), var(--secondary-color));
        border-radius: 12px;
        opacity: 0;
        transition: var(--transition);
        z-index: -1;
    }

    .tip-image:hover::after {
        opacity: 0.1;
    }

    .tip-details {
        flex: 1;
    }

    .tip-name {
        color: var(--primary-color);
        font-size: 24px;
        font-weight: 800;
        margin-bottom: 5px;
        line-height: 1.3;
        display: flex;
        align-items: center;
        gap: 10px;
    }

    .tip-model {
        color: var(--dark-gray);
        font-size: 17px;
        font-weight: 500;
        margin-bottom: 25px;
        padding-bottom: 15px;
        border-bottom: 2px solid rgba(0, 0, 0, 0.08);
    }

    .specs-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
        gap: 18px;
        margin: 25px 0;
    }

    .spec-item {
        background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
        padding: 18px;
        border-radius: 10px;
        text-align: center;
        border: 1px solid rgba(0, 0, 0, 0.08);
        transition: var(--transition);
        position: relative;
        overflow: hidden;
    }

    .spec-item:hover {
        background: white;
        border-color: var(--accent-color);
        transform: translateY(-3px);
        box-shadow: 0 6px 20px rgba(21, 101, 192, 0.15);
    }

    .spec-item::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        width: 5px;
        height: 100%;
        background: linear-gradient(to bottom, var(--accent-color), var(--secondary-color));
        opacity: 0;
        transition: var(--transition);
    }

    .spec-item:hover::before {
        opacity: 1;
    }

    .spec-label {
        color: var(--dark-gray);
        font-size: 13px;
        text-transform: uppercase;
        letter-spacing: 0.8px;
        margin-bottom: 10px;
        font-weight: 700;
    }

    .spec-value {
        color: var(--primary-color);
        font-size: 20px;
        font-weight: 800;
    }

    .droplet-info {
        background: linear-gradient(135deg, var(--light-blue) 0%, #90caf9 100%);
        padding: 15px 25px;
        border-radius: 30px;
        display: inline-flex;
        align-items: center;
        gap: 12px;
        margin: 20px 0;
        border: 2px solid #64b5f6;
        box-shadow: 0 4px 12px rgba(33, 150, 243, 0.2);
        transition: var(--transition);
    }

    .droplet-info:hover {
        transform: scale(1.02);
        box-shadow: 0 6px 20px rgba(33, 150, 243, 0.3);
    }

    .droplet-icon {
        color: var(--accent-color);
        font-size: 22px;
        animation: bounce 2s ease infinite;
    }

    .droplet-text {
        color: var(--accent-color);
        font-weight: 700;
        font-size: 16px;
    }

    .additional-info {
        margin-top: 30px;
        padding-top: 25px;
        border-top: 2px dashed rgba(0, 0, 0, 0.1);
    }

    .info-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        gap: 18px;
    }

    .info-item {
        background: linear-gradient(135deg, #fafafa 0%, #f0f0f0 100%);
        padding: 18px 20px;
        border-radius: 10px;
        border-left: 4px solid var(--secondary-color);
        transition: var(--transition);
    }

    .info-item:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 20px rgba(0, 0, 0, 0.08);
    }

    .info-label {
        font-weight: 700;
        color: var(--dark-gray);
        font-size: 13px;
        text-transform: uppercase;
        letter-spacing: 0.8px;
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        gap: 8px;
    }

    .info-value {
        color: var(--text-color);
        font-size: 15px;
        font-weight: 500;
        line-height: 1.5;
    }

    .footer {
        background: linear-gradient(135deg, var(--primary-color) 0%, #0d1f3d 100%);
        color: white;
        padding: 35px 25px;
        text-align: center;
        margin-top: 50px;
        position: relative;
        overflow: hidden;
    }

    .footer::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 5px;
        background: linear-gradient(90deg, var(--secondary-color), #66bb6a, var(--accent-color));
    }

    .footer::after {
        content: "";
        position: absolute;
        bottom: 0;
        left: 0;
        width: 200px;
        height: 200px;
        background: radial-gradient(circle, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 70%);
    }

    .footer-content {
        max-width: 650px;
        margin: 0 auto;
        position: relative;
        z-index: 1;
    }

    .footer-title {
        font-size: 20px;
        font-weight: 700;
        margin-bottom: 15px;
        opacity: 0.95;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 10px;
    }

    .footer-text {
        font-size: 14px;
        opacity: 0.8;
        line-height: 1.6;
    }

    .footer-text strong {
        color: #bbdefb;
    }

    @keyframes gradient-shift {
        0% { background-position: 0% 50%; }
        50% { background-position: 100% 50%; }
        100% { background-position: 0% 50%; }
    }

    @keyframes bounce {
        0%, 100% { transform: translateY(0); }
        50% { transform: translateY(-5px); }
    }

    @keyframes fadeIn {
        from { 
            opacity: 0; 
            transform: translateY(30px) scale(0.98); 
        }
        to { 
            opacity: 1; 
            transform: translateY(0) scale(1); 
        }
    }

    .tip-card {
        animation: fadeIn 0.6s cubic-bezier(0.4, 0, 0.2, 1) forwards;
        opacity: 0;
    }

    .tip-card:nth-child(1) { animation-delay: 0.1s; }
    .tip-card:nth-child(2) { animation-delay: 0.2s; }
    .tip-card:nth-child(3) { animation-delay: 0.3s; }
    .tip-card:nth-child(4) { animation-delay: 0.4s; }
    .tip-card:nth-child(5) { animation-delay: 0.5s; }

    @media print {
        body {
            background: white !important;
            padding: 0 !important;
            font-size: 12pt !important;
        }
        
        .container {
            box-shadow: none !important;
            border: 2px solid #ddd !important;
            max-width: 100% !important;
            margin: 0 !important;
        }
        
        .tip-card:hover,
        .spec-item:hover,
        .user-info:hover {
            transform: none !important;
            box-shadow: none !important;
        }
        
        .header,
        .footer {
            background: var(--primary-color) !important;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }
        
        .summary {
            background: #f0f0f0 !important;
            border: 1px solid #ccc !important;
        }
        
        .tip-number {
            background: #333 !important;
        }
    }

    @media (max-width: 600px) {
        body {
            padding: 15px;
        }
        
        .title {
            font-size: 24px;
        }
        
        .subtitle {
            font-size: 14px;
        }
        
        .user-info {
            padding: 20px;
            gap: 15px;
        }
        
        .user-avatar,
        .avatar-fallback {
            width: 60px;
            height: 60px;
            font-size: 24px;
        }
        
        .tip-image-container {
            width: 150px;
            height: 150px;
        }
        
        .specs-grid {
            grid-template-columns: 1fr;
        }
        
        .info-grid {
            grid-template-columns: 1fr;
        }
    }
</style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="title">📋 LISTA DE PONTAS FAVORITAS MAGNOJET</h1>
            <p class="subtitle">Gerado em: $formattedDate</p>
        </div>
    ''');

      if (_userName.isNotEmpty && _userName != 'Usuário') {
        htmlContent.write('''
    <div class="user-info">
  ''');

        if (_userAvatarUrl != null && _userAvatarUrl!.isNotEmpty) {
          try {
            final avatarBase64 = await _imageToBase64(_userAvatarUrl!);
            if (avatarBase64.isNotEmpty) {
              htmlContent.write('''
        <img src="$avatarBase64" 
             alt="Foto do usuário" 
             class="user-avatar">
      ''');
            } else {
              htmlContent.write('''
        <div class="avatar-fallback">${_userName.substring(0, 1).toUpperCase()}</div>
      ''');
            }
          } catch (e) {
            htmlContent.write('''
        <div class="avatar-fallback">${_userName.substring(0, 1).toUpperCase()}</div>
      ''');
          }
        } else {
          htmlContent.write('''
        <div class="avatar-fallback">${_userName.substring(0, 1).toUpperCase()}</div>
      ''');
        }

        htmlContent.write('''
        <div class="user-details">
            <p class="user-name">$_userName</p>
            <p class="user-date">Gerado em: $formattedDateTime</p>
        </div>
    </div>
    ''');
      }

      htmlContent.write('''
        <div class="summary">
            <h2>📊 Resumo da Lista</h2>
            <p>Total de <strong>${filteredFavorites.length} ponta${filteredFavorites.length != 1 ? 's' : ''}</strong> favoritada${filteredFavorites.length != 1 ? 's' : ''}</p>
        </div>
    ''');

      for (int i = 0; i < filteredFavorites.length; i++) {
        final tip = filteredFavorites[i];
        final String dropletSize = (tip.dropletSizeId != null &&
                tip.dropletSizeId! > 0)
            ? _dropletSizeMap[tip.dropletSizeId] ?? 'ID: ${tip.dropletSizeId}'
            : 'N/A';

        htmlContent.write('''
        <div class="tip-card">
            <div class="tip-number">${i + 1}</div>
            <div class="tip-content">
                <div class="tip-header">
                    <div class="tip-image-container">
      ''');

        if (tip.imageUrl != null && tip.imageUrl!.isNotEmpty) {
          try {
            final imageBase64 = await _imageToBase64(tip.imageUrl!);
            if (imageBase64.isNotEmpty) {
              htmlContent.write('''
          <img src="$imageBase64" 
               alt="${tip.name}" 
               class="tip-image">
        ''');
            } else {
              final fallbackSvg = '''
data:image/svg+xml;base64,${base64Encode(utf8.encode('''<svg xmlns="http://www.w3.org/2000/svg" width="150" height="150" viewBox="0 0 24 24">
  <rect width="100%" height="100%" fill="#f5f5f5"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="#ccc" font-size="14">${tip.name.substring(0, math.min(tip.name.length, 10))}</text>
</svg>'''))}''';
              htmlContent.write('''
          <img src="$fallbackSvg" alt="${tip.name}" class="tip-image">
        ''');
            }
          } catch (e) {
            final fallbackSvg = '''
data:image/svg+xml;base64,${base64Encode(utf8.encode('''<svg xmlns="http://www.w3.org/2000/svg" width="150" height="150" viewBox="0 0 24 24">
  <rect width="100%" height="100%" fill="#f5f5f5"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="#ccc" font-size="14">Sem Imagem</text>
</svg>'''))}''';
            htmlContent.write('''
          <img src="$fallbackSvg" alt="${tip.name}" class="tip-image">
        ''');
          }
        } else {
          final fallbackSvg = '''
data:image/svg+xml;base64,${base64Encode(utf8.encode('''<svg xmlns="http://www.w3.org/2000/svg" width="150" height="150" viewBox="0 0 24 24">
  <rect width="100%" height="100%" fill="#f5f5f5"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="#ccc" font-size="14">Sem Imagem</text>
</svg>'''))}''';
          htmlContent.write('''
          <img src="$fallbackSvg" alt="Sem imagem" class="tip-image">
        ''');
        }

        htmlContent.write('''
                    </div>
                    <div class="tip-details">
                        <h2 class="tip-name">${tip.name} - ${tip.model}</h2>
                        
                        <div class="specs-grid">
                            <div class="spec-item">
                                <div class="spec-label">Vazão</div>
                                <div class="spec-value">${tip.flowRate} L/min</div>
                            </div>
                            <div class="spec-item">
                                <div class="spec-label">Pressão</div>
                                <div class="spec-value">${tip.pressure} bar</div>
                            </div>
                            <div class="spec-item">
                                <div class="spec-label">Espaçamento</div>
                                <div class="spec-value">${tip.spacing.toStringAsFixed(1)} cm</div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="droplet-info">
                    <span class="droplet-icon">💧</span>
                    <span class="droplet-text">Tamanho da gota: <strong>$dropletSize</strong></span>
                </div>
      ''');

        if (tip.modoAcao != null && tip.modoAcao!.isNotEmpty ||
            tip.aplicacao != null && tip.aplicacao!.isNotEmpty) {
          htmlContent.write('''
            <div class="additional-info">
                <div class="info-grid">
        ''');

          if (tip.modoAcao != null && tip.modoAcao!.isNotEmpty) {
            htmlContent.write('''
                <div class="info-item">
                    <div class="info-label">Modo de Ação</div>
                    <div class="info-value">${tip.modoAcao}</div>
                </div>
          ''');
          }

          if (tip.aplicacao != null && tip.aplicacao!.isNotEmpty) {
            htmlContent.write('''
                <div class="info-item">
                    <div class="info-label">Aplicação</div>
                    <div class="info-value">${tip.aplicacao}</div>
                </div>
          ''');
          }

          htmlContent.write('''
                </div>
            </div>
        ''');
        }

        htmlContent.write('''
            </div>
        </div>
      ''');
      }

      htmlContent.write('''
        <div class="footer">
            <div class="footer-content">
                <div class="footer-title">Magnojet • Qualidade e Precisão a Serviço da Agricultura.</div>
                <div class="footer-text">
                    Documento gerado automaticamente em  $formattedDateTime<br>
                    Para uso exclusivo do aplicativo Magnojet • ${DateTime.now().year}
                </div>
            </div>
        </div>
    </div>
</body>
</html>
    ''');

      final directory = await getTemporaryDirectory();
      final htmlFile = File('${directory.path}/pontas_favoritas.html');
      await htmlFile.writeAsString(htmlContent.toString(), flush: true);

      if (mounted) {
        Navigator.pop(context);
      }

      await SharePlus.instance.share(
        ShareParams(
          text: 'Confira minha lista de pontas favoritas da Magnojet! 🚜',
          subject: 'Lista de Pontas Favoritas - Magnojet',
          files: [XFile(htmlFile.path)],
        ),
      );

      Future.delayed(const Duration(minutes: 2), () async {
        try {
          if (htmlFile.existsSync()) {
            await htmlFile.delete();
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
                          '${tip.flowRate} L/min',
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
              onPressed: _shareFavoritesList,
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
