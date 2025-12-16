class CatalogItem {
  final int id;
  final String title;
  final String description;
  final String fileName;
  final String fileUrl;
  final String fileSize;
  final String category;
  final String version;
  final DateTime lastUpdated;
  final String thumbnailUrl;

  CatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.category,
    required this.version,
    required this.lastUpdated,
    required this.thumbnailUrl,
  });

  String get formattedDate {
    return '${lastUpdated.day.toString().padLeft(2, '0')}/${lastUpdated.month.toString().padLeft(2, '0')}/${lastUpdated.year}';
  }
}
