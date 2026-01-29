class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final NotificationType type;
  final DateTime scheduledAt;
  final DateTime? createdAt;
  final bool isRead;
  final String? userId;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    required this.type,
    required this.scheduledAt,
    this.createdAt,
    this.isRead = false,
    this.userId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      imageUrl: json['image_url'],
      data:
          json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      type: NotificationType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'general'),
        orElse: () => NotificationType.general,
      ),
      scheduledAt: DateTime.parse(json['scheduled_at']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      isRead: json['is_read'] ?? false,
      userId: json['user_id'],
    );
  }
}

enum NotificationType {
  general,
  alert,
  update,
  reminder,
  promotion,
}
