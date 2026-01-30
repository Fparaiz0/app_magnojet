import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:magnojet/models/catalog_model.dart';
import 'package:magnojet/pages/auth/login_page.dart';
import 'package:magnojet/pages/home/favorites_page.dart';
import 'package:magnojet/pages/home/history_page.dart';
import 'package:magnojet/pages/home/home_page.dart';
import 'package:magnojet/pages/home/profile_page.dart';
import 'package:magnojet/pages/home/settings_page.dart';
import 'package:magnojet/pages/home/tip_selection_page.dart';
import 'package:magnojet/widgets/custom_drawer.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final Map<int, double> _downloadingItems = {};
  final Map<int, String> _downloadedFiles = {};

  String _userName = 'Usuário';
  String? _userAvatarUrl;
  bool _isLoadingUser = true;
  bool _isLoadingCatalog = false;
  bool _isAuthenticated = false;
  final List<CatalogItem> _catalogItems = [];

  static const Color primaryColor = Color(0xFF15325A);
  static const Color secondaryColor = Color(0xFF1E88E5);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color successColor = Color(0xFF28A745);
  static const Color borderColor = Color(0xFFE9ECEF);
  static const String _downloadedFilesKey = 'downloaded_files';

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    final User? user = supabase.auth.currentUser;
    _isAuthenticated = user != null;

    if (_isAuthenticated) {
      await _loadUserData();
    } else {
      setState(() => _isLoadingUser = false);
    }

    await _loadCatalogItems();
    await _loadDownloadedFiles();
    await _checkExistingDownloads();
  }

  Future<void> _loadDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_downloadedFilesKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);

        setState(() {
          _downloadedFiles.clear();
          jsonMap.forEach((key, value) {
            _downloadedFiles[int.parse(key)] = value.toString();
          });
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> jsonMap = {};

      _downloadedFiles.forEach((key, value) {
        jsonMap[key.toString()] = value;
      });

      final jsonString = json.encode(jsonMap);
      await prefs.setString(_downloadedFilesKey, jsonString);
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    if (!_isAuthenticated) {
      setState(() {
        _userName = 'Usuário';
        _userAvatarUrl = null;
        _isLoadingUser = false;
      });
      return;
    }

    final User? user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _userName = 'Usuário';
        _userAvatarUrl = null;
        _isLoadingUser = false;
        _isAuthenticated = false;
      });
      return;
    }

    final userEmail = user.email ?? '';
    final metadata = user.userMetadata ?? {};

    String name = metadata['name']?.toString() ??
        metadata['full_name']?.toString() ??
        metadata['username']?.toString() ??
        userEmail.split('@').first;

    if (name.isEmpty) name = 'Usuário';

    String? avatarUrl = metadata['avatar_url']?.toString();
    if (avatarUrl != null && avatarUrl.isEmpty) avatarUrl = null;

    setState(() {
      _userName = name;
      _userAvatarUrl = avatarUrl;
    });

    try {
      final response = await supabase
          .from('users')
          .select('name, avatar_url')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response is Map) {
        final userNameFromTable = response?['name'] as String?;
        final userAvatarFromTable = response?['avatar_url'] as String?;

        if (mounted) {
          setState(() {
            if (userNameFromTable != null && userNameFromTable.isNotEmpty) {
              _userName = userNameFromTable;
            }
            if (userAvatarFromTable != null && userAvatarFromTable.isNotEmpty) {
              _userAvatarUrl = userAvatarFromTable;
            }
            _isLoadingUser = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadCatalogItems() async {
    if (mounted) setState(() => _isLoadingCatalog = true);

    try {
      final response = await supabase
          .from('catalogs')
          .select(
              'id, title, description, file_name, file_url, file_size, category, version, created_at, thumbnail_url, is_active')
          .order('created_at', ascending: false)
          .limit(50);

      final List<dynamic> data = response;
      final List<CatalogItem> loadedItems = [];

      for (final item in data) {
        try {
          final Map<String, dynamic> itemMap;
          if (item is Map<String, dynamic>) {
            itemMap = item;
          } else {
            itemMap = Map<String, dynamic>.from(item as Map);
          }

          final isActive = itemMap['is_active'] as bool? ?? true;
          if (!isActive) continue;

          loadedItems.add(CatalogItem(
            id: (itemMap['id'] as num?)?.toInt() ?? 0,
            title: (itemMap['title'] as String?) ?? 'Sem título',
            description: (itemMap['description'] as String?) ?? '',
            fileName: (itemMap['file_name'] as String?) ?? 'arquivo.pdf',
            fileUrl: (itemMap['file_url'] as String?) ?? '',
            fileSize: (itemMap['file_size'] as String?) ?? 'N/A',
            category: (itemMap['category'] as String?) ?? 'Geral',
            version: (itemMap['version'] as String?) ?? '1.0',
            lastUpdated: itemMap['created_at'] != null
                ? DateTime.parse(itemMap['created_at'] as String)
                : DateTime.now(),
            thumbnailUrl: (itemMap['thumbnail_url'] as String?) ??
                'https://cdn-icons-png.flaticon.com/512/337/337946.png',
          ));
        } catch (e) {
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _catalogItems.clear();
          _catalogItems.addAll(loadedItems);
          _isLoadingCatalog = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCatalog = false);
      _loadMockCatalogs();
    }
  }

  void _loadMockCatalogs() {
    final mockItems = [
      CatalogItem(
        id: 1,
        title: 'Catálogo de Produtos 2024',
        description:
            'Catálogo completo de produtos com especificações técnicas',
        fileName: 'catalogo_produtos_2024.pdf',
        fileUrl: 'https://example.com/catalogo.pdf',
        fileSize: '15 MB',
        category: 'Produtos',
        version: '2.1',
        lastUpdated: DateTime.now(),
        thumbnailUrl: 'https://cdn-icons-png.flaticon.com/512/337/337946.png',
      ),
    ];

    if (mounted) {
      setState(() {
        _catalogItems.clear();
        _catalogItems.addAll(mockItems);
        _isLoadingCatalog = false;
      });
    }
  }

  Future<bool> _checkAndRequestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkVersion = androidInfo.version.sdkInt;

        if (sdkVersion >= 33) return true;
        if (sdkVersion >= 29) return true;

        final status = await Permission.storage.status;
        if (status.isPermanentlyDenied) {
          _showPermissionSettingsDialog();
          return false;
        }
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          return result.isGranted;
        }
        return true;
      } else if (Platform.isIOS) {
        return true;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissão Negada'),
        content: const Text(
          'A permissão de armazenamento foi negada permanentemente. '
          'Você precisa permitir manualmente nas configurações do aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkExistingDownloads() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsPath = '${directory.path}/MagnoJet_Downloads';
      final dir = Directory(downloadsPath);

      if (await dir.exists()) {
        final files = await dir.list().toList();

        for (final fileEntity in files) {
          if (fileEntity is File) {
            final fileName = fileEntity.path.split('/').last;

            for (final item in _catalogItems) {
              if (item.fileName == fileName) {
                _downloadedFiles[item.id] = fileEntity.path;
                break;
              }
            }
          }
        }

        await _saveDownloadedFiles();
      }
    } catch (_) {}
  }

  Future<void> _downloadAndOpenCatalog(CatalogItem item) async {
    if (!_isAuthenticated) {
      _showLoginRequiredDialog();
      return;
    }

    final hasPermission = await _checkAndRequestStoragePermission();
    if (!hasPermission) {
      return;
    }

    setState(() {
      _downloadingItems[item.id] = 0.0;
    });

    http.Client? client;
    IOSink? fileSink;
    final completer = Completer<void>();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsPath = '${directory.path}/MagnoJet_Downloads';
      final filePath = '$downloadsPath/${item.fileName}';

      final dir = Directory(downloadsPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      client = http.Client();
      final request = http.Request('GET', Uri.parse(item.fileUrl));
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final file = File(filePath);
        fileSink = file.openWrite();

        final totalLength = response.contentLength ?? 0;
        int receivedLength = 0;

        response.stream.listen(
          (List<int> chunk) {
            receivedLength += chunk.length;
            fileSink?.add(chunk);

            if (totalLength > 0) {
              final progress = receivedLength / totalLength;

              if (mounted) {
                setState(() {
                  _downloadingItems[item.id] = progress;
                });
              }
            }
          },
          onDone: () async {
            await fileSink?.flush();
            await fileSink?.close();
            client?.close();

            final fileSize = await file.length();

            if (fileSize > 0) {
              await _recordDownload(item.id);

              if (mounted) {
                setState(() {
                  _downloadedFiles[item.id] = filePath;
                  _downloadingItems.remove(item.id);
                });
              }

              await _saveDownloadedFiles();
              _showSuccessSnackbar('✅ Download concluído!');

              final savedFile = File(filePath);
              final exists = await savedFile.exists();

              if (exists) {
                await _openDownloadedFile(item.id);
              } else {
                _showErrorSnackbar('❌ Arquivo não foi salvo corretamente');
              }
            } else {
              _showErrorSnackbar('❌ Arquivo vazio (0 bytes)');
            }

            completer.complete();
          },
          onError: (e) async {
            await fileSink?.close();
            client?.close();

            if (mounted) {
              setState(() {
                _downloadingItems.remove(item.id);
              });
            }

            _showErrorSnackbar('❌ Falha no download');
            completer.completeError(e);
          },
        );

        await completer.future;
      } else {
        client.close();
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackbar('❌ Erro: ${e.toString()}');

      fileSink?.close();
      client?.close();

      if (mounted) {
        setState(() {
          _downloadingItems.remove(item.id);
        });
      }

      completer.completeError(e);
    }
  }

  Future<void> _openDownloadedFile(int itemId) async {
    final filePath = _downloadedFiles[itemId];
    if (filePath != null) {
      try {
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          _showErrorSnackbar('Não foi possível abrir o arquivo');
        }
      } catch (e) {
        _showErrorSnackbar('Erro ao abrir arquivo: $e');
      }
    }
  }

  Future<void> _deleteDownloadedFile(int itemId) async {
    final filePath = _downloadedFiles[itemId];
    if (filePath != null) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          setState(() => _downloadedFiles.remove(itemId));
          await _saveDownloadedFiles();
          _showSuccessSnackbar('Arquivo removido');
        }
      } catch (e) {
        _showErrorSnackbar('Erro ao remover arquivo');
      }
    }
  }

  Future<void> _recordDownload(int catalogId) async {
    if (!_isAuthenticated) return;

    try {
      final User? user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('catalog_downloads').insert({
          'catalog_id': catalogId,
          'user_id': user.id,
          'downloaded_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login necessário'),
        content: const Text('Você precisa fazer login para baixar catálogos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('Fazer Login'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: successColor,
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDownloadProgress(double progress) {
    final percentage = (progress * 100).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(secondaryColor),
            borderRadius: BorderRadius.circular(8),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text(
            'Baixando... $percentage%',
            style: const TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(CatalogItem item) {
    final bool isDownloading = _downloadingItems.containsKey(item.id);
    final bool isDownloaded = _downloadedFiles.containsKey(item.id);

    if (isDownloading) {
      final progress = _downloadingItems[item.id] ?? 0.0;
      return _buildDownloadProgress(progress);
    } else if (isDownloaded) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openDownloadedFile(item.id),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Abrir Arquivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showDeleteDialog(item),
            icon:
                Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
            tooltip: 'Remover arquivo',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => _downloadAndOpenCatalog(item),
        icon: const Icon(Icons.download_rounded, size: 16),
        label: const Text('Baixar Catálogo'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }
  }

  void _showDeleteDialog(CatalogItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Arquivo'),
        content: Text('Deseja remover "${item.title}" do seu dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDownloadedFile(item.id);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogItem(CatalogItem item, int index) {
    final bool isDownloaded = _downloadedFiles.containsKey(item.id);

    return Container(
      margin: EdgeInsets.fromLTRB(20, index == 0 ? 20 : 10, 20, 10),
      child: Material(
        color: cardColor,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDownloaded ? () => _openDownloadedFile(item.id) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(item, isDownloaded),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(item, isDownloaded),
                          const SizedBox(height: 8),
                          _buildDescription(item),
                          const SizedBox(height: 16),
                          _buildMetadata(item),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildActionButtons(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(CatalogItem item, bool isDownloaded) {
    return Container(
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.thumbnailUrl,
                fit: BoxFit.contain,
                width: 90,
                height: 90,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 30,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  );
                },
              ),
            ),
          ),
          if (isDownloaded)
            Positioned(
              top: -2,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: successColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: successColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(CatalogItem item, bool isDownloaded) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDownloaded)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: successColor),
                      ),
                      child: const Text(
                        'Baixado',
                        style: TextStyle(
                          fontSize: 10,
                          color: successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(CatalogItem item) {
    return Text(
      item.description,
      style: const TextStyle(
        fontSize: 14,
        color: textSecondary,
        height: 1.5,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetadata(CatalogItem item) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildInfoChip('V${item.version}', Icons.update_rounded),
        _buildInfoChip(item.fileSize, Icons.insert_drive_file_rounded),
        _buildInfoChip(item.formattedDate, Icons.calendar_today_rounded),
      ],
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_rounded,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            const Text(
              'Nenhum catálogo disponível',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              !_isAuthenticated
                  ? 'Faça login para ver os catálogos disponíveis'
                  : 'Os catálogos aparecerão aqui quando disponíveis',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 24),
            if (!_isAuthenticated)
              ElevatedButton.icon(
                onPressed: _navigateToLogin,
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                label: const Text('Fazer Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () async {
                  await _loadCatalogItems();
                  await _checkExistingDownloads();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          child: Card(
            color: cardColor,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 80,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
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
      },
    );
  }

  Widget _buildCatalogList() {
    if (_catalogItems.isEmpty && !_isLoadingCatalog) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCatalogItems();
        await _checkExistingDownloads();
      },
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 20, bottom: 20),
        itemCount: _catalogItems.length,
        itemBuilder: (context, index) =>
            _buildCatalogItem(_catalogItems[index], index),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Saída'),
        content: const Text('Tem certeza que deseja sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorSnackbar('Erro ao sair da conta');
    }
  }

  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Catálogo',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await _loadCatalogItems();
              await _checkExistingDownloads();
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      drawer: _isAuthenticated
          ? CustomDrawer(
              currentRoute: '/catalog',
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
                  MaterialPageRoute(
                      builder: (context) => const TipSelectionPage()),
                  (route) => false,
                );
              },
              onFavoritesTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FavoritesPage()),
                );
              },
              onCatalogTap: () {
                Navigator.pop(context);
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
              onLogoutTap: _showLogoutDialog,
            )
          : null,
      body: SafeArea(
        child: _isLoadingCatalog && _catalogItems.isEmpty
            ? _buildLoadingShimmer()
            : _buildCatalogList(),
      ),
    );
  }
}
