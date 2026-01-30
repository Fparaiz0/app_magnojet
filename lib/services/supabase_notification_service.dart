import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:magnojet/models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

abstract class NotificationService {
  Future<void> initialize();
  Future<String?> getDeviceToken();
  Future<void> saveTokenToSupabase(String token);
  Future<void> deleteTokenFromSupabase(String token);
  Future<void> sendNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    NotificationType type = NotificationType.general,
    String? userId,
    DateTime? scheduleAt,
  });
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduleAt,
    String? imageUrl,
    Map<String, dynamic>? data,
    NotificationType type = NotificationType.reminder,
    String? userId,
  });
  Future<List<AppNotification>> getUserNotifications({int limit = 50});
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> handleBackgroundMessage(RemoteMessage message);
  Future<void> handleForegroundMessage(RemoteMessage message);
  Future<void> handleTapNotification(NotificationResponse response);
  Stream<RemoteMessage> get onMessageOpenedApp;
  Stream<RemoteMessage> get onMessage;
}

class SupabaseNotificationService implements NotificationService {
  final SupabaseClient supabase;
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final String? currentUserId;

  static const String deviceTokensTable = 'device_tokens';
  static const String notificationsTable = 'notifications';
  static const String scheduledNotificationsTable = 'scheduled_notifications';
  static const String notificationSettingsTable = 'notification_settings';

  final Uuid _uuid = const Uuid();
  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();

  SupabaseNotificationService({
    required this.supabase,
    required FirebaseMessaging firebaseMessaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    this.currentUserId,
  })  : _firebaseMessaging = firebaseMessaging,
        _localNotifications = localNotifications;

  @override
  Future<void> initialize() async {
    try {
      await _setupLocalNotifications();

      await _setupFirebaseMessaging();

      await _registerToken();

      _setupMessageListeners();

      await _createDefaultSettings();

      debugPrint('✅ NotificationService inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar NotificationService: $e');
      rethrow;
    }
  }

  Future<void> _setupLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleTapNotification,
        onDidReceiveBackgroundNotificationResponse:
            _onDidReceiveBackgroundNotificationResponse,
      );

      if (!kIsWeb && Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'Notificações Importantes',
          description: 'Este canal é usado para notificações importantes',
          importance: Importance.max,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
    } catch (e) {
      debugPrint('❌ Erro ao configurar notificações locais: $e');
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission();

      debugPrint('📱 Status da permissão: ${settings.authorizationStatus}');

      if (!kIsWeb && Platform.isIOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao configurar Firebase Messaging: $e');
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await getDeviceToken();
      if (token != null) {
        await saveTokenToSupabase(token);
        debugPrint(
            '✅ Token registrado: ${token.substring(0, (token.length > 20 ? 20 : token.length))}...');
      } else {
        debugPrint('⚠️ Token FCM não disponível');
      }
    } catch (e) {
      debugPrint('❌ Erro ao registrar token: $e');
    }
  }

  void _setupMessageListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _messageStreamController.add(message);
      handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _messageStreamController.add(message);
      handleForegroundMessage(message);
    });

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint(
          '🔄 Token atualizado: ${newToken.substring(0, (newToken.length > 20 ? 20 : newToken.length))}...');
      await saveTokenToSupabase(newToken);
    });
  }

  Future<void> _createDefaultSettings() async {
    if (currentUserId == null) return;

    try {
      await supabase.from(notificationSettingsTable).upsert({
        'user_id': currentUserId,
        'push_enabled': true,
        'general_enabled': true,
        'alert_enabled': true,
        'update_enabled': true,
        'reminder_enabled': true,
        'promotion_enabled': true,
        'message_enabled': true,
        'order_enabled': true,
        'quiet_enabled': true,
        'quiet_start': '22:00',
        'quiet_end': '08:00',
      });
    } catch (e) {
      debugPrint('⚠️ Erro ao criar configurações padrão: $e');
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    try {
      if (kIsWeb) {
        return await _firebaseMessaging.getToken(
          vapidKey: 'WEB_VAPID_KEY_AQUI',
        );
      } else {
        return await _firebaseMessaging.getToken();
      }
    } catch (e) {
      debugPrint('❌ Erro ao obter token: $e');
      return null;
    }
  }

  @override
  Future<void> saveTokenToSupabase(String token) async {
    if (currentUserId == null) {
      debugPrint('⚠️ currentUserId é null, token não salvo');
      return;
    }

    try {
      await supabase.from(deviceTokensTable).upsert({
        'device_token': token,
        'user_id': currentUserId,
        'platform': _getPlatform(),
        'app_version': await _getAppVersion(),
        'device_model': await _getDeviceModel(),
        'os_version': await _getOsVersion(),
        'is_active': true,
        'last_active': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Token salvo no Supabase');
    } catch (e) {
      debugPrint('❌ Erro ao salvar token no Supabase: $e');
    }
  }

  @override
  Future<void> deleteTokenFromSupabase(String token) async {
    try {
      await supabase
          .from(deviceTokensTable)
          .update({'is_active': false}).eq('device_token', token);

      debugPrint('✅ Token marcado como inativo');
    } catch (e) {
      debugPrint('❌ Erro ao deletar token do Supabase: $e');
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  Future<String> _getAppVersion() async {
    return '1.0.0';
  }

  Future<String> _getDeviceModel() async {
    return 'Unknown';
  }

  Future<String> _getOsVersion() async {
    return 'Unknown';
  }

  @override
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('📱 Notificação em background recebida');

    try {
      await _showLocalNotification(
        title: message.notification?.title ?? 'Nova notificação',
        body: message.notification?.body ?? '',
        data: message.data,
      );

      await _saveNotificationToDatabase(message);
    } catch (e) {
      debugPrint('❌ Erro em handleBackgroundMessage: $e');
    }
  }

  @override
  Future<void> handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Notificação em foreground recebida');

    try {
      final isQuiet = await _isQuietTime();
      if (isQuiet) {
        debugPrint('⏰ Modo silencioso ativo, notificação não exibida');
        return;
      }

      final notificationType = message.data['type'] ?? 'general';
      final isTypeEnabled = await _isNotificationTypeEnabled(notificationType);
      if (!isTypeEnabled) {
        debugPrint('🔕 Tipo de notificação $notificationType desabilitado');
        return;
      }

      await _showLocalNotification(
        title: message.notification?.title ?? 'Nova notificação',
        body: message.notification?.body ?? '',
        data: message.data,
      );

      await _saveNotificationToDatabase(message);
    } catch (e) {
      debugPrint('❌ Erro em handleForegroundMessage: $e');
    }
  }

  Future<void> _saveNotificationToDatabase(RemoteMessage message) async {
    if (currentUserId == null) return;

    try {
      final notificationId = _uuid.v4();

      await supabase.from(notificationsTable).insert({
        'id': notificationId,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'image_url': message.notification?.android?.imageUrl ??
            message.notification?.apple?.imageUrl,
        'data': message.data,
        'type': message.data['type'] ?? 'general',
        'user_id': currentUserId,
        'is_read': false,
        'is_delivered': true,
        'delivered_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Notificação salva no banco: $notificationId');
    } catch (e) {
      debugPrint('❌ Erro ao salvar notificação no banco: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'Notificações Importantes',
        channelDescription: 'Este canal é usado para notificações importantes',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: data != null ? json.encode(data) : null,
      );

      debugPrint('✅ Notificação local exibida: $title');
    } catch (e) {
      debugPrint('❌ Erro ao exibir notificação local: $e');
    }
  }

  @override
  Future<void> sendNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    NotificationType type = NotificationType.general,
    String? userId,
    DateTime? scheduleAt,
  }) async {
    try {
      if (userId != null) {
        final userSettings = await supabase
            .from(notificationSettingsTable)
            .select('push_enabled, ${type.name}_enabled')
            .eq('user_id', userId as Object)
            .single()
            .timeout(const Duration(seconds: 5));

        if (userSettings['push_enabled'] != true ||
            userSettings['${type.name}_enabled'] != true) {
          debugPrint('🔕 Usuário desabilitou notificações do tipo $type');
          return;
        }
      }

      final response = await supabase.functions.invoke(
        'send-notification',
        body: {
          'title': title,
          'body': body,
          'imageUrl': imageUrl,
          'data': data ?? {},
          'type': type.name,
          'userId': userId,
          'scheduleAt': scheduleAt?.toIso8601String(),
        },
      );

      if (response.status >= 400) {
        throw Exception(
            'Erro ao enviar notificação: Status ${response.status}');
      }

      debugPrint('✅ Notificação enviada com sucesso');
    } catch (e) {
      debugPrint('❌ Erro no sendNotification: $e');
      rethrow;
    }
  }

  @override
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduleAt,
    String? imageUrl,
    Map<String, dynamic>? data,
    NotificationType type = NotificationType.reminder,
    String? userId,
  }) async {
    try {
      if (scheduleAt.isBefore(DateTime.now())) {
        throw Exception('Não é possível agendar notificação no passado');
      }

      await supabase.from(scheduledNotificationsTable).insert({
        'id': _uuid.v4(),
        'title': title,
        'body': body,
        'image_url': imageUrl,
        'data': data ?? {},
        'type': type.name,
        'scheduled_at': scheduleAt.toIso8601String(),
        'user_id': userId ?? currentUserId,
        'status': 'scheduled',
        'max_retries': 3,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Notificação agendada para ${scheduleAt.toString()}');
    } catch (e) {
      debugPrint('❌ Erro ao agendar notificação: $e');
      rethrow;
    }
  }

  @override
  Future<List<AppNotification>> getUserNotifications({int limit = 50}) async {
    if (currentUserId == null) return [];

    try {
      final response = await supabase
          .from(notificationsTable)
          .select()
          .eq('user_id', currentUserId as Object)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 10));

      final notifications = (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();

      debugPrint('✅ ${notifications.length} notificações carregadas');
      return notifications;
    } catch (e) {
      debugPrint('❌ Erro ao buscar notificações: $e');
      return [];
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    if (currentUserId == null) return;

    try {
      await supabase
          .from(notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', currentUserId as Object);

      debugPrint('✅ Notificação $notificationId marcada como lida');
    } catch (e) {
      debugPrint('❌ Erro ao marcar como lida: $e');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    if (currentUserId == null) return;

    try {
      await supabase
          .from(notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', currentUserId as Object)
          .eq('is_read', false);

      debugPrint('✅ Todas as notificações marcadas como lidas');
    } catch (e) {
      debugPrint('❌ Erro ao marcar todas como lidas: $e');
    }
  }

  @override
  Future<void> handleTapNotification(NotificationResponse response) async {
    debugPrint('👆 Notificação clicada');

    try {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final data = json.decode(response.payload!) as Map<String, dynamic>;

        if (data['notification_id'] != null) {
          await markAsRead(data['notification_id']);
        }

        debugPrint('📱 Payload da notificação: $data');
      }
    } catch (e) {
      debugPrint('❌ Erro ao processar clique na notificação: $e');
    }
  }

  Future<bool> _isQuietTime() async {
    if (currentUserId == null) return false;

    try {
      final settings = await supabase
          .from(notificationSettingsTable)
          .select('quiet_enabled, quiet_start, quiet_end')
          .eq('user_id', currentUserId as Object)
          .single()
          .timeout(const Duration(seconds: 3));

      if (settings['quiet_enabled'] != true) return false;

      final now = TimeOfDay.fromDateTime(DateTime.now());
      final quietStart = _parseTime(settings['quiet_start']);
      final quietEnd = _parseTime(settings['quiet_end']);

      if (quietStart == null || quietEnd == null) return false;

      if (quietStart.hour > quietEnd.hour) {
        return now.hour >= quietStart.hour || now.hour < quietEnd.hour;
      } else {
        return now.hour >= quietStart.hour && now.hour < quietEnd.hour;
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar modo silencioso: $e');
      return false;
    }
  }

  TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      debugPrint('❌ Erro ao parsear tempo: $timeString');
    }
    return null;
  }

  Future<bool> _isNotificationTypeEnabled(String type) async {
    if (currentUserId == null) return true;

    try {
      final settings = await supabase
          .from(notificationSettingsTable)
          .select('${type}_enabled')
          .eq('user_id', currentUserId as Object)
          .single()
          .timeout(const Duration(seconds: 3));

      return settings['${type}_enabled'] == true;
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar tipo de notificação: $e');
      return true;
    }
  }

  Future<void> _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    debugPrint('📱 Notificação local recebida: $title');
  }

  @pragma('vm:entry-point')
  static Future<void> _onDidReceiveBackgroundNotificationResponse(
      NotificationResponse response) async {
    debugPrint('📱 Notificação em background clicada');
  }

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<Map<String, dynamic>> getUserSettings() async {
    if (currentUserId == null) return {};

    try {
      final settings = await supabase
          .from(notificationSettingsTable)
          .select()
          .eq('user_id', currentUserId as Object)
          .single()
          .timeout(const Duration(seconds: 5));

      return settings;
    } catch (e) {
      debugPrint('❌ Erro ao buscar configurações: $e');
      return {};
    }
  }

  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    if (currentUserId == null) return;

    try {
      await supabase
          .from(notificationSettingsTable)
          .update(settings)
          .eq('user_id', currentUserId as Object);

      debugPrint('✅ Configurações atualizadas');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar configurações: $e');
      rethrow;
    }
  }
}
