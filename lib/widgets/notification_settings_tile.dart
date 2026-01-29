import 'package:flutter/material.dart';
import '../services/notification_permission_service.dart';

class NotificationSettingsTile extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color activeColor;
  final Color inactiveColor;
  final bool showStatus;
  final Function(bool)? onToggleChanged;

  const NotificationSettingsTile({
    super.key,
    this.title = 'Notificações',
    this.description = 'Receba notificações importantes',
    this.icon = Icons.notifications_active_rounded,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.showStatus = true,
    this.onToggleChanged,
  });

  @override
  State<NotificationSettingsTile> createState() =>
      _NotificationSettingsTileState();
}

class _NotificationSettingsTileState extends State<NotificationSettingsTile> {
  final NotificationPermissionService _service =
      NotificationPermissionService();
  late Future<NotificationSettings> _settingsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    if (!mounted) return;
    setState(() {
      _settingsFuture = _service.getNotificationSettings();
    });
  }

  Future<void> _handleToggle(bool enable) async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = await _service.toggleNotifications(enable);

      if (!mounted) return;

      if (!result.success) {
        await _handleToggleError(result);
      } else {
        _showToggleSnackbar(result.enabled);
        widget.onToggleChanged?.call(result.enabled);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Erro inesperado: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _loadSettings();
    }
  }

  Future<void> _handleToggleError(ToggleResult result) async {
    if (!mounted) return;

    if (result.reason == ToggleReason.permissionDenied) {
      await _showPermissionDeniedDialog(result.permissionResult!);
    } else {
      _showErrorSnackbar(result.error ?? 'Erro desconhecido');
    }
  }

  Future<void> _showPermissionDeniedDialog(
    PermissionRequestResult permissionResult,
  ) async {
    if (!mounted) return;

    final isPermanentlyDenied = permissionResult.permanentlyDenied;
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          isPermanentlyDenied ? 'Permissão Bloqueada' : 'Permissão Necessária',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          isPermanentlyDenied
              ? 'Você bloqueou as notificações no dispositivo.\n\n'
                  'Para ativar, vá em:\n'
                  'Configurações → Apps → MagnoJet → Notificações'
              : 'Para receber notificações, você precisa permitir o acesso no dispositivo.',
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Entendi',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (isPermanentlyDenied)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _service.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Abrir Configurações'),
            ),
        ],
      ),
    );
  }

  void _showToggleSnackbar(bool enabled) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              enabled ? Icons.notifications_active : Icons.notifications_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                enabled
                    ? 'Notificações ativadas com sucesso!'
                    : 'Notificações desativadas',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: enabled ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatusIndicator(NotificationSettings settings) {
    if (!widget.showStatus) return const SizedBox();

    final Color color;
    final IconData icon;
    final String text;

    if (settings.isEffectivelyEnabled) {
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'Ativo';
    } else if (settings.permissionStatus.isPermanentlyDenied) {
      color = Colors.red;
      icon = Icons.block;
      text = 'Bloqueado';
    } else if (settings.permissionStatus.isDenied) {
      color = Colors.orange;
      icon = Icons.warning;
      text = 'Permissão necessária';
    } else {
      color = Colors.grey;
      icon = Icons.info;
      text = 'Inativo';
    }

    if (settings.shouldShowRationale && !settings.permissionStatus.isGranted) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRationaleCard(NotificationSettings settings) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por que ativar notificações?',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Receba alertas importantes, atualizações em tempo real e nunca perca informações relevantes do app.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: Colors.grey, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Carregando configurações...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorTile(dynamic error) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Erro de Configuração',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Não foi possível carregar as configurações',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadSettings,
            color: Colors.blue,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotificationSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingTile();
        }

        if (snapshot.hasError) {
          return _buildErrorTile(snapshot.error);
        }

        final settings = snapshot.data!;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: settings.isEffectivelyEnabled
                          ? widget.activeColor.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      color: settings.isEffectivelyEnabled
                          ? widget.activeColor
                          : widget.inactiveColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        _buildStatusIndicator(settings),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _isLoading
                      ? SizedBox(
                          width: 48,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                settings.isEffectivelyEnabled
                                    ? widget.activeColor
                                    : widget.inactiveColor,
                              ),
                            ),
                          ),
                        )
                      : Transform.scale(
                          scale: 0.9,
                          child: Switch.adaptive(
                            value: settings.isEffectivelyEnabled,
                            onChanged: _handleToggle,
                            activeTrackColor: widget.activeColor,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: widget.inactiveColor,
                            inactiveThumbColor: Colors.white,
                            trackOutlineColor: WidgetStateProperty.resolveWith(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return widget.activeColor
                                      .withValues(alpha: 0.5);
                                }
                                return widget.inactiveColor
                                    .withValues(alpha: 0.5);
                              },
                            ),
                          ),
                        ),
                ],
              ),
            ),
            if (settings.shouldShowRationale &&
                !settings.permissionStatus.isGranted)
              _buildRationaleCard(settings),
          ],
        );
      },
    );
  }
}
