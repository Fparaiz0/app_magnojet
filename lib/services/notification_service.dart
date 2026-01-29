import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';

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
  Future<List<AppNotification>> getUserNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> handleBackgroundMessage(RemoteMessage message);
  Future<void> handleForegroundMessage(RemoteMessage message);
  Future<void> handleTapNotification(NotificationResponse response);
}
