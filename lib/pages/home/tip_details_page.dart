import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import '../../models/tip_selection_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_drawer.dart';
import 'favorites_page.dart';
import '../auth/login_page.dart';
import 'home_page.dart';
import 'tip_selection_page.dart';
import 'settings_page.dart';
import 'history_page.dart';
import 'catalog_page.dart';
import 'profile_page.dart';

class TipDetailsPage extends StatefulWidget {
  final TipModel tip;
  final Map<int, String> dropletSizeMap;
  final double speed;
  final bool hasPWM;

  const TipDetailsPage({
    super.key,
    required this.tip,
    required this.dropletSizeMap,
    required this.speed,
    required this.hasPWM,
  });

  @override
  State<TipDetailsPage> createState() => _TipDetailsPageState();
}

class _TipDetailsPageState extends State<TipDetailsPage> {
  late final SupabaseClient supabase;
  String _userName = '';
  String? _userAvatarUrl;
  bool _isLoadingUser = true;
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  bool _isSharing = false;

  static const primaryColor = Color(0xFF15325A);
  static const backgroundColor = Color(0xFFF5F7FA);
  static const accentColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;
    _loadUserData();
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
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

  Future<void> _checkFavoriteStatus() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoadingFavorite = false);
      return;
    }

    try {
      final response = await supabase
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('tip_id', widget.tip.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorite = response != null;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFavorite = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Faça login para salvar favoritos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_isLoadingFavorite) return;

    if (mounted) setState(() => _isLoadingFavorite = true);

    try {
      if (_isFavorite) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('tip_id', widget.tip.id);

        if (mounted) {
          setState(() => _isFavorite = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removido dos favoritos'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await supabase.from('favorites').insert({
          'user_id': user.id,
          'tip_id': widget.tip.id,
        });

        if (mounted) {
          setState(() => _isFavorite = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adicionado aos favoritos'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _shareTipDetails() async {
    if (_isSharing) return;

    if (mounted) {
      setState(() => _isSharing = true);
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 16),
              Text('Gerando arquivo para compartilhamento...'),
            ],
          ),
        ),
      );

      final now = DateTime.now();
      final formattedDateTime =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final tip = widget.tip;
      final dropletSize = widget.dropletSizeMap[tip.dropletSizeId] ?? 'N/A';

      double flowRatePerHectare = 0.0;
      final denominator = (tip.spacing / 100) * widget.speed;
      if (denominator != 0) {
        flowRatePerHectare = (tip.flowRate * 600) / denominator;
      }

      final StringBuffer htmlContent = StringBuffer();

      htmlContent.write('''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${tip.name} - ${tip.model} - Magnojet</title>
    <style>
        :root {
            --primary-color: #15325A;
            --secondary-color: #4CAF50;
            --accent-color: #1565c0;
            --success-color: #2e7d32;
            --info-color: #0288d1;
            --warning-color: #f57c00;
            --danger-color: #d32f2f;
            --light-blue: #e3f2fd;
            --light-green: #e8f5e9;
            --light-orange: #fff3e0;
            --light-gray: #f5f5f5;
            --medium-gray: #e0e0e0;
            --dark-gray: #616161;
            --text-color: #263238;
            --border-radius: 16px;
            --border-radius-sm: 12px;
            --border-radius-lg: 20px;
            --box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08);
            --box-shadow-hover: 0 16px 40px rgba(0, 0, 0, 0.12);
            --box-shadow-light: 0 4px 20px rgba(0, 0, 0, 0.05);
            --transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
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
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            min-height: 100vh;
            padding: 30px 20px;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }

        .container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            border-radius: var(--border-radius-lg);
            box-shadow: var(--box-shadow);
            overflow: hidden;
            border: 1px solid rgba(21, 50, 90, 0.08);
            position: relative;
        }

        .header {
            background: linear-gradient(135deg, var(--primary-color) 0%, #0d1f3d 100%);
            color: white;
            padding: 50px 40px;
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
            height: 6px;
            background: linear-gradient(90deg, var(--secondary-color), #66bb6a, var(--accent-color));
            background-size: 300% 100%;
            animation: gradient-shift 4s ease infinite;
        }

        .header::after {
            content: "";
            position: absolute;
            top: 0;
            right: 0;
            width: 200px;
            height: 200px;
            background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0) 70%);
        }

        .title {
            font-size: 32px;
            font-weight: 800;
            margin-bottom: 12px;
            letter-spacing: -0.5px;
            position: relative;
            z-index: 1;
            text-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
            line-height: 1.3;
        }

        .subtitle {
            font-size: 16px;
            opacity: 0.95;
            font-weight: 400;
            letter-spacing: 0.3px;
            position: relative;
            z-index: 1;
        }

        .tip-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(255, 255, 255, 0.15);
            padding: 8px 20px;
            border-radius: 50px;
            margin-top: 15px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            font-size: 14px;
            font-weight: 600;
        }

        .content {
            padding: 40px;
        }

        .tip-image-container {
            width: 100%;
            max-width: 350px;
            height: 350px;
            margin: 0 auto 40px;
            position: relative;
        }

        .tip-image {
            width: 100%;
            height: 100%;
            object-fit: contain;
            border: 3px solid var(--medium-gray);
            border-radius: var(--border-radius);
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            padding: 25px;
            transition: var(--transition);
            position: relative;
            z-index: 1;
        }

        .tip-image:hover {
            border-color: var(--accent-color);
            transform: scale(1.02);
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.1);
        }

        .tip-image::after {
            content: "";
            position: absolute;
            top: -6px;
            left: -6px;
            right: -6px;
            bottom: -6px;
            background: linear-gradient(135deg, var(--accent-color), var(--secondary-color));
            border-radius: calc(var(--border-radius) + 4px);
            opacity: 0;
            transition: var(--transition);
            z-index: -1;
        }

        .tip-image:hover::after {
            opacity: 0.08;
        }

        .section {
            margin: 35px 0;
            padding: 28px;
            background: white;
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow-light);
            border: 1px solid rgba(0, 0, 0, 0.06);
            transition: var(--transition);
            position: relative;
            overflow: hidden;
        }

        .section:hover {
            box-shadow: var(--box-shadow-hover);
            transform: translateY(-2px);
        }

        .section::before {
            content: "";
            position: absolute;
            left: 0;
            top: 0;
            bottom: 0;
            width: 6px;
            background: linear-gradient(to bottom, var(--primary-color), var(--accent-color));
            opacity: 0;
            transition: var(--transition);
        }

        .section:hover::before {
            opacity: 1;
        }

        .section-title {
            color: var(--primary-color);
            font-size: 20px;
            font-weight: 800;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 12px;
            letter-spacing: -0.3px;
        }

        .section-title i {
            font-size: 22px;
            opacity: 0.9;
        }

        .specs-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 25px 0;
        }

        .spec-item {
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            padding: 22px;
            border-radius: var(--border-radius-sm);
            text-align: center;
            border: 1px solid rgba(0, 0, 0, 0.08);
            transition: var(--transition);
            position: relative;
            overflow: hidden;
        }

        .spec-item:hover {
            background: white;
            border-color: var(--accent-color);
            transform: translateY(-4px);
            box-shadow: 0 10px 30px rgba(21, 101, 192, 0.12);
        }

        .spec-item::before {
            content: "";
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
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
            letter-spacing: 1px;
            margin-bottom: 12px;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }

        .spec-value {
            color: var(--primary-color);
            font-size: 24px;
            font-weight: 800;
            letter-spacing: -0.5px;
        }

        .spec-icon {
            color: var(--accent-color);
            font-size: 16px;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }

        .info-item {
            background: linear-gradient(135deg, #fafafa 0%, #f0f4f8 100%);
            padding: 22px;
            border-radius: var(--border-radius-sm);
            border-left: 5px solid var(--secondary-color);
            transition: var(--transition);
        }

        .info-item:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
        }

        .info-label {
            font-weight: 700;
            color: var(--dark-gray);
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .info-value {
            color: var(--text-color);
            font-size: 16px;
            font-weight: 500;
            line-height: 1.6;
        }

        .calculation-box {
            background: linear-gradient(135deg, var(--light-green) 0%, #b2dfdb 100%);
            padding: 30px;
            border-radius: var(--border-radius);
            border: 2px solid rgba(46, 125, 50, 0.25);
            margin: 30px 0;
            position: relative;
            overflow: hidden;
        }

        .calculation-box::before {
            content: "";
            position: absolute;
            top: 0;
            right: 0;
            width: 150px;
            height: 150px;
            background: radial-gradient(circle, rgba(76, 175, 80, 0.1) 0%, rgba(76, 175, 80, 0) 70%);
        }

        .calculation-value {
            font-size: 42px;
            font-weight: 800;
            color: var(--success-color);
            margin: 15px 0;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            letter-spacing: -1px;
        }

        .calculation-subtitle {
            color: var(--success-color);
            font-size: 14px;
            font-weight: 600;
            opacity: 0.9;
        }

        .warning-section {
            background: linear-gradient(135deg, #fff3e0 0%, #ffe0b2 100%);
            border: 2px solid rgba(245, 124, 0, 0.3);
            padding: 25px;
            border-radius: var(--border-radius);
            margin: 25px 0;
        }

        .warning-title {
            color: var(--warning-color);
            font-size: 18px;
            font-weight: 700;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .warning-text {
            color: #e65100;
            font-size: 15px;
            line-height: 1.6;
        }

        .tips-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 16px;
            margin-top: 20px;
        }

        .tip-item {
            background: linear-gradient(135deg, #f8fafc 0%, #e3f2fd 100%);
            padding: 20px;
            border-radius: var(--border-radius-sm);
            border-left: 4px solid var(--accent-color);
            transition: var(--transition);
        }

        .tip-item:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.08);
        }

        .tip-bullet {
            display: inline-block;
            width: 24px;
            height: 24px;
            background: var(--accent-color);
            color: white;
            border-radius: 50%;
            text-align: center;
            line-height: 24px;
            font-weight: bold;
            margin-right: 12px;
            font-size: 12px;
        }

        .footer {
            background: linear-gradient(135deg, var(--primary-color) 0%, #0d1f3d 100%);
            color: white;
            padding: 40px 30px;
            text-align: center;
            margin-top: 40px;
            position: relative;
            overflow: hidden;
        }

        .footer::before {
            content: "";
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 6px;
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
            max-width: 700px;
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
            gap: 12px;
        }

        .footer-text {
            font-size: 14px;
            opacity: 0.8;
            line-height: 1.7;
        }

        .footer-text strong {
            color: #bbdefb;
            font-weight: 600;
        }

        @keyframes gradient-shift {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }

        @keyframes fadeIn {
            from { 
                opacity: 0; 
                transform: translateY(20px) scale(0.98); 
            }
            to { 
                opacity: 1; 
                transform: translateY(0) scale(1); 
            }
        }

        .section {
            animation: fadeIn 0.5s cubic-bezier(0.4, 0, 0.2, 1) forwards;
            animation-delay: calc(var(--index, 0) * 0.1s);
            opacity: 0;
        }

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
            
            .section:hover,
            .spec-item:hover,
            .tip-item:hover {
                transform: none !important;
                box-shadow: none !important;
            }
            
            .header,
            .footer {
                background: var(--primary-color) !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }
            
            .calculation-box {
                background: #f0f0f0 !important;
                border: 1px solid #ccc !important;
            }
        }

        @media (max-width: 768px) {
            body {
                padding: 20px 15px;
            }
            
            .header {
                padding: 35px 25px;
            }
            
            .title {
                font-size: 26px;
            }
            
            .subtitle {
                font-size: 14px;
            }
            
            .content {
                padding: 30px 25px;
            }
            
            .tip-image-container {
                height: 280px;
                max-width: 280px;
            }
            
            .specs-grid {
                grid-template-columns: 1fr;
                gap: 16px;
            }
            
            .section {
                padding: 22px;
                margin: 25px 0;
            }
            
            .section-title {
                font-size: 18px;
            }
            
            .spec-value {
                font-size: 22px;
            }
            
            .calculation-value {
                font-size: 36px;
            }
        }

        @media (max-width: 480px) {
            .header {
                padding: 30px 20px;
            }
            
            .title {
                font-size: 22px;
            }
            
            .content {
                padding: 25px 20px;
            }
            
            .tip-image-container {
                height: 220px;
                max-width: 220px;
            }
            
            .section {
                padding: 20px;
            }
            
            .specs-grid,
            .info-grid,
            .tips-grid {
                grid-template-columns: 1fr;
            }
            
            .footer {
                padding: 30px 20px;
            }
            
            .footer-title {
                font-size: 18px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="title">${tip.name} - ${tip.model}</h1>
            <p class="subtitle">Ficha Técnica - Magnojet • Gerado em: $formattedDateTime</p>
        </div>
        
        <div class="content">
            <div class="tip-image-container">
''');

      if (tip.imageUrl != null && tip.imageUrl!.isNotEmpty) {
        try {
          final imageBase64 = await _imageToBase64(tip.imageUrl!);
          if (imageBase64.isNotEmpty) {
            htmlContent.write('''
                <img src="$imageBase64" alt="${tip.name}" class="tip-image">
''');
          } else {
            final fallbackSvg = '''
data:image/svg+xml;base64,${base64Encode(utf8.encode('''<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 24 24">
  <rect width="100%" height="100%" fill="#f5f5f5"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="#ccc" font-size="16">${tip.name.substring(0, math.min(tip.name.length, 15))}</text>
</svg>'''))}''';
            htmlContent.write('''
                <img src="$fallbackSvg" alt="${tip.name}" class="tip-image">
''');
          }
        } catch (e) {
          final fallbackSvg = '''
data:image/svg+xml;base64,${base64Encode(utf8.encode('''<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 24 24">
  <rect width="100%" height="100%" fill="#f5f5f5"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="#ccc" font-size="16">Sem Imagem</text>
</svg>'''))}''';
          htmlContent.write('''
              <img src="$fallbackSvg" alt="${tip.name}" class="tip-image">
''');
        }
      } else {
        final fallbackSvg = '''
data:image/svg+xml;base64,${base64Encode(utf8.encode('''<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 24 24">
  <rect width="100%" height="100%" fill="#f5f5f5"/>
  <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="#ccc" font-size="16">Sem Imagem</text>
</svg>'''))}''';
        htmlContent.write('''
            <img src="$fallbackSvg" alt="Sem imagem" class="tip-image">
''');
      }

      htmlContent.write('''
            </div>
            
            <div class="section">
                <h2 class="section-title">📊 Especificações Técnicas</h2>
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
                        <div class="spec-value">${tip.spacing.toStringAsFixed(0)} cm</div>
                    </div>
                    <div class="spec-item">
                        <div class="spec-label">Tamanho da Gota</div>
                        <div class="spec-value">$dropletSize</div>
                    </div>
                </div>
            </div>
            
            <div class="calculation-box">
                <h2 class="section-title">🧮 Cálculo de Aplicação</h2>
                <div class="specs-grid">
                    <div class="spec-item">
                        <div class="spec-label">Velocidade</div>
                        <div class="spec-value">${widget.speed} km/h</div>
                    </div>
                    <div class="spec-item">
                        <div class="spec-label">Tecnologia</div>
                        <div class="spec-value">${widget.hasPWM ? 'PWM' : 'Sem PWM'}</div>
                    </div>
                </div>
                <div class="calculation-value">${flowRatePerHectare.toStringAsFixed(0)} L/ha</div>
                <p style="color: var(--dark-gray); font-size: 13px; margin-top: 8px;">
                    Vazão por hectare calculada com ${widget.speed} km/h e ${tip.spacing.toStringAsFixed(0)} cm de espaçamento
                </p>
            </div>
''');

      if (tip.modoAcao != null && tip.modoAcao!.isNotEmpty) {
        htmlContent.write('''
            <div class="section">
                <h2 class="section-title">ℹ️ Modo de Ação</h2>
                <div class="info-item">
                    <div class="info-value">${tip.modoAcao}</div>
                </div>
            </div>
''');
      }

      if (tip.aplicacao != null && tip.aplicacao!.isNotEmpty) {
        htmlContent.write('''
            <div class="section">
                <h2 class="section-title">🎯 Tipo de Aplicação</h2>
                <div class="info-item">
                    <div class="info-value">${tip.aplicacao}</div>
                </div>
            </div>
''');
      }

      if (tip.pressure > 5.0) {
        htmlContent.write('''
            <div class="warning-section">
                <h2 class="warning-title">⚠️ Atenção: Pressão Alta</h2>
                <p class="warning-text">
                    Esta ponta opera em pressão acima de 5 bar (${tip.pressure} bar). 
                    Considere trabalhar em pressões mais baixas para melhor eficiência e menor desgaste do equipamento.
                </p>
            </div>
''');
      }

      htmlContent.write('''
            <div class="section">
                <h2 class="section-title">💡 Dicas de Aplicação</h2>
                <div class="tips-grid">
                    <div class="tip-item">
                        <span class="tip-bullet">1</span>
                        Verifique sempre a compatibilidade da ponta com o produto a ser aplicado.
                    </div>
                    <div class="tip-item">
                        <span class="tip-bullet">2</span>
                        Mantenha a pressão dentro dos limites recomendados pela MagnoJet.
                    </div>
                    <div class="tip-item">
                        <span class="tip-bullet">3</span>
                        Realize calibração periódica do equipamento.
                    </div>
                    <div class="tip-item">
                        <span class="tip-bullet">4</span>
                        Limpar os bicos de pulverização apenas com produtos neutros.
                    </div>
                    <div class="tip-item">
                        <span class="tip-bullet">5</span>
                        Observe as condições climáticas durante a aplicação.
                    </div>
                    <div class="tip-item">
                        <span class="tip-bullet">6</span>
                        Use EPI adequado durante a aplicação.
                    </div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <div class="footer-text">
                <strong>Magnojet • Qualidade e Precisão a Serviço da Agricultura.</strong><br>
                Documento gerado automaticamente em $formattedDateTime<br>
                Para uso exclusivo do aplicativo Magnojet • ${DateTime.now().year}
            </div>
        </div>
    </div>
</body>
</html>
''');

      final directory = await getTemporaryDirectory();

      String fileName =
          '${tip.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}_${tip.model.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_')}.html';
      fileName = fileName.replaceAll('__', '_').replaceAll('_.', '.');

      final htmlFile = File('${directory.path}/$fileName');
      await htmlFile.writeAsString(htmlContent.toString(), flush: true);

      if (mounted) {
        Navigator.pop(context);
      }

      await SharePlus.instance.share(
        ShareParams(
          text:
              'Confira a ficha técnica da ponta ${tip.name} - ${tip.model} da Magnojet! 🚜\n\nVazão: ${tip.flowRate} L/min • Pressão: ${tip.pressure} bar\nTamanho da gota: $dropletSize',
          subject: 'Ficha Técnica: ${tip.name} - ${tip.model} - Magnojet',
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
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
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

  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: primaryColor),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    final hasModoAcao =
        widget.tip.modoAcao != null && widget.tip.modoAcao!.isNotEmpty;
    final hasAplicacao =
        widget.tip.aplicacao != null && widget.tip.aplicacao!.isNotEmpty;

    if (!hasModoAcao && !hasAplicacao) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
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
              Icon(Icons.info_outline_rounded, color: primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Informações Adicionais',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15325A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasModoAcao) ...[
            _buildInfoCard(
              title: 'Modo de Ação',
              value: widget.tip.modoAcao!,
              icon: Icons.touch_app_rounded,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
          ],
          if (hasAplicacao) ...[
            _buildInfoCard(
              title: 'Tipo de Aplicação',
              value: widget.tip.aplicacao!,
              icon: Icons.science_rounded,
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPressureWarning() {
    if (widget.tip.pressure <= 5.0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atenção: Pressão Alta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Esta ponta opera em pressão acima de 5 bar. Considere trabalhar em pressões mais baixas para melhor eficiência e menor desgaste.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final imageUrl = widget.tip.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported_rounded,
                  size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Imagem não disponível',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
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
                strokeWidth: 3,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded,
                    size: 40, color: Colors.red.shade400),
                const SizedBox(height: 8),
                Text(
                  'Erro ao carregar imagem',
                  style: TextStyle(color: Colors.red.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecificationsSection() {
    final dropletSize =
        widget.dropletSizeMap[widget.tip.dropletSizeId] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(top: 16),
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
              Icon(Icons.tune_rounded, color: primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Especificações Técnicas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15325A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                      'Pressão',
                      '${widget.tip.pressure} bar',
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDetailRow(
                      'Vazão',
                      '${widget.tip.flowRate} L/min',
                      icon: Icons.water_drop_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                      'Espaçamento',
                      '${widget.tip.spacing.toStringAsFixed(0)} cm',
                      icon: Icons.straighten_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDetailRow(
                      'Tamanho da Gota',
                      dropletSize,
                      icon: Icons.opacity_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                      'Tecnologia',
                      widget.hasPWM ? 'PWM' : 'Sem PWM',
                      icon: Icons.flash_on_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDetailRow(
                      'Velocidade',
                      '${widget.speed} km/h',
                      icon: Icons.directions_car_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationInfo() {
    double flowRatePerHectare = 0.0;
    final denominator = (widget.tip.spacing / 100) * widget.speed;

    if (denominator != 0) {
      flowRatePerHectare = (widget.tip.flowRate * 600) / denominator;
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
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
          const Text(
            'Cálculos de Aplicação',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vazão por Hectare:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${flowRatePerHectare.toStringAsFixed(0)} L/ha',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Com ${widget.speed} km/h e ${widget.tip.spacing.toStringAsFixed(0)} cm de espaçamento',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Fórmula: Vazão (L/ha) = (Vazão (L/min) × 600) ÷ (Espaçamento (m) × Velocidade (km/h))',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationTips() {
    final tips = <String>[
      'Verifique sempre a compatibilidade da ponta com o produto a ser aplicado.',
      'Mantenha a pressão dentro dos limites recomendados pela MagnoJet.',
      'Realize calibração periódica do equipamento.',
      'Limpar os bicos de pulverização apenas com produtos neutros.',
      'Observe as condições climáticas durante a aplicação.',
      'Use EPI adequado durante a aplicação.',
    ];

    return Container(
      margin: const EdgeInsets.only(top: 16),
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
          const Text(
            'Dicas de Aplicação',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: tips
                .map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _compareTips() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Funcionalidade de comparação em desenvolvimento'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Detalhes da Ponta',
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
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_rounded),
            onPressed: _isSharing ? null : _shareTipDetails,
          ),
          IconButton(
            icon: _isLoadingFavorite
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isFavorite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _isFavorite ? Colors.amber : Colors.white,
                  ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      drawer: CustomDrawer(
        currentRoute: '/tip-details',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.tip.name} - ${widget.tip.model}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Ponta Recomendada',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_isFavorite) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.bookmark_rounded,
                                  size: 14, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                'Favorita',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildImageSection(),
                const SizedBox(height: 20),
                _buildPressureWarning(),
                _buildSpecificationsSection(),
                _buildAdditionalInfoSection(),
                _buildCalculationInfo(),
                _buildApplicationTips(),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Voltar para Lista'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _compareTips,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.compare_arrows_rounded),
                          label: const Text('Comparar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
