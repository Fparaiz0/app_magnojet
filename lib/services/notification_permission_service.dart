import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ToggleReason {
  enabled,
  disabled,
  permissionDenied,
  error,
}

class NotificationPermissionStatus {
  final bool isGranted;
  final bool isDenied;
  final bool isPermanentlyDenied;
  final bool isLimited;
  final bool isRestricted;
  final String platformStatus;
  final String? error;

  const NotificationPermissionStatus({
    required this.isGranted,
    required this.isDenied,
    this.isPermanentlyDenied = false,
    this.isLimited = false,
    this.isRestricted = false,
    this.platformStatus = 'unknown',
    this.error,
  });

  @override
  String toString() {
    return 'NotificationPermissionStatus('
        'isGranted: $isGranted, '
        'isDenied: $isDenied, '
        'isPermanentlyDenied: $isPermanentlyDenied'
        ')';
  }
}

class PermissionRequestResult {
  final bool granted;
  final bool denied;
  final bool permanentlyDenied;
  final String status;
  final String? error;

  const PermissionRequestResult({
    required this.granted,
    required this.denied,
    this.permanentlyDenied = false,
    this.status = 'unknown',
    this.error,
  });

  @override
  String toString() {
    return 'PermissionRequestResult('
        'granted: $granted, '
        'denied: $denied, '
        'permanentlyDenied: $permanentlyDenied'
        ')';
  }
}

class ToggleResult {
  final bool success;
  final bool enabled;
  final ToggleReason reason;
  final PermissionRequestResult? permissionResult;
  final String? error;

  const ToggleResult({
    required this.success,
    required this.enabled,
    required this.reason,
    this.permissionResult,
    this.error,
  });

  @override
  String toString() {
    return 'ToggleResult('
        'success: $success, '
        'enabled: $enabled, '
        'reason: $reason'
        ')';
  }
}

class NotificationSettings {
  final bool userPreference;
  final NotificationPermissionStatus permissionStatus;
  final bool isEffectivelyEnabled;
  final bool canRequestPermission;
  final bool shouldShowRationale;
  final String? error;

  const NotificationSettings({
    required this.userPreference,
    required this.permissionStatus,
    required this.isEffectivelyEnabled,
    this.canRequestPermission = true,
    this.shouldShowRationale = false,
    this.error,
  });

  @override
  String toString() {
    return 'NotificationSettings('
        'userPreference: $userPreference, '
        'isEffectivelyEnabled: $isEffectivelyEnabled, '
        'canRequestPermission: $canRequestPermission'
        ')';
  }
}

class NotificationPermissionService {
  static final NotificationPermissionService _instance =
      NotificationPermissionService._internal();

  factory NotificationPermissionService() => _instance;
  NotificationPermissionService._internal();

  static const String _prefKey = 'notifications_enabled';
  static const String _permissionRequestedKey = 'permission_requested';

  Future<void> initialize() async {
    try {
      await SharedPreferences.getInstance();
      if (kDebugMode) {
        print('✅ Serviço de permissões inicializado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao inicializar serviço: $e');
      }
    }
  }

  Future<NotificationPermissionStatus> getPermissionStatus() async {
    try {
      final PermissionStatus status = await Permission.notification.status;

      return NotificationPermissionStatus(
        isGranted: status.isGranted,
        isDenied: status.isDenied,
        isPermanentlyDenied: status.isPermanentlyDenied,
        isLimited: status.isLimited,
        isRestricted: status.isRestricted,
        platformStatus: status.toString(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao verificar permissão: $e');
      }
      return NotificationPermissionStatus(
        isGranted: false,
        isDenied: true,
        error: e.toString(),
      );
    }
  }

  Future<PermissionRequestResult> requestPermission() async {
    try {
      if (kDebugMode) {
        print('🔔 Solicitando permissão de notificação...');
      }

      final PermissionStatus status = await Permission.notification.request();

      await _markPermissionRequested();

      final result = PermissionRequestResult(
        granted: status.isGranted,
        denied: status.isDenied,
        permanentlyDenied: status.isPermanentlyDenied,
        status: status.toString(),
      );

      if (kDebugMode) {
        print('📋 Resultado da permissão: ${result.granted ? "✅" : "❌"}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao solicitar permissão: $e');
      }
      return PermissionRequestResult(
        granted: false,
        denied: true,
        error: e.toString(),
      );
    }
  }

  Future<ToggleResult> toggleNotifications(bool enable) async {
    try {
      if (enable) {
        final permissionResult = await requestPermission();

        if (!permissionResult.granted) {
          return ToggleResult(
            success: false,
            enabled: false,
            reason: ToggleReason.permissionDenied,
            permissionResult: permissionResult,
          );
        }
      }

      await _saveUserPreference(enable);

      if (kDebugMode) {
        print('💾 Preferência salva: $enable');
      }

      return ToggleResult(
        success: true,
        enabled: enable,
        reason: enable ? ToggleReason.enabled : ToggleReason.disabled,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao alternar notificações: $e');
      }
      return ToggleResult(
        success: false,
        enabled: !enable,
        reason: ToggleReason.error,
        error: e.toString(),
      );
    }
  }

  Future<NotificationSettings> getNotificationSettings() async {
    try {
      final userPref = await _getUserPreference();
      final permissionStatus = await getPermissionStatus();

      final settings = NotificationSettings(
        userPreference: userPref,
        permissionStatus: permissionStatus,
        isEffectivelyEnabled: userPref && permissionStatus.isGranted,
        canRequestPermission: !permissionStatus.isPermanentlyDenied,
        shouldShowRationale: await _shouldShowRationale(),
      );

      if (kDebugMode) {
        print('📊 Configurações carregadas: $settings');
      }

      return settings;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao obter configurações: $e');
      }
      return NotificationSettings(
        userPreference: false,
        permissionStatus: await getPermissionStatus(),
        isEffectivelyEnabled: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> hasRequestedPermissionBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_permissionRequestedKey) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao verificar histórico: $e');
      }
      return false;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
      if (kDebugMode) {
        print('⚙️ Configurações do app abertas');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao abrir configurações: $e');
      }
      rethrow;
    }
  }

  Future<bool> getUserPreference() async {
    return await _getUserPreference();
  }

  Future<void> setUserPreference(bool enabled) async {
    await _saveUserPreference(enabled);
  }

  Future<void> _saveUserPreference(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao salvar preferência: $e');
      }
      rethrow;
    }
  }

  Future<bool> _getUserPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao ler preferência: $e');
      }
      return true;
    }
  }

  Future<void> _markPermissionRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionRequestedKey, true);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao marcar permissão solicitada: $e');
      }
    }
  }

  Future<bool> _shouldShowRationale() async {
    try {
      if (!await hasRequestedPermissionBefore()) {
        return true;
      }

      final status = await getPermissionStatus();

      return status.isDenied && !status.isPermanentlyDenied;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao verificar rationale: $e');
      }
      return false;
    }
  }

  Future<bool> areNotificationsFunctional() async {
    final settings = await getNotificationSettings();
    return settings.isEffectivelyEnabled;
  }

  Future<void> resetAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      await prefs.remove(_permissionRequestedKey);

      if (kDebugMode) {
        print('🔄 Configurações resetadas');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao resetar configurações: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = await getNotificationSettings();
      final permissionStatus = await getPermissionStatus();

      return {
        'user_preference': settings.userPreference,
        'permission_granted': permissionStatus.isGranted,
        'permission_denied': permissionStatus.isDenied,
        'permission_permanently_denied': permissionStatus.isPermanentlyDenied,
        'effectively_enabled': settings.isEffectivelyEnabled,
        'can_request_permission': settings.canRequestPermission,
        'should_show_rationale': settings.shouldShowRationale,
        'has_requested_before': await hasRequestedPermissionBefore(),
        'platform_status': permissionStatus.platformStatus,
        'shared_preferences_working': prefs.containsKey(_prefKey),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
