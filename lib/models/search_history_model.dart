class SearchHistoryModel {
  final int id;
  final String userId;
  final String parametersJson;
  final String resultsJson;
  final DateTime searchDate;
  final int? resultCount;

  SearchHistoryModel({
    required this.id,
    required this.userId,
    required this.parametersJson,
    required this.resultsJson,
    required this.searchDate,
    this.resultCount,
  });

  factory SearchHistoryModel.fromJson(Map<String, dynamic> json) {
    return SearchHistoryModel(
      id: json['id'],
      userId: json['user_id'],
      parametersJson: json['parameters_json'],
      resultsJson: json['results_json'],
      searchDate: DateTime.parse(json['search_date']),
      resultCount: json['result_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'parameters_json': parametersJson,
      'results_json': resultsJson,
      'search_date': searchDate.toIso8601String(),
      'result_count': resultCount,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'parameters_json': parametersJson,
      'results_json': resultsJson,
      'search_date': searchDate.toIso8601String(),
      'result_count': resultCount,
    };
  }
}
