enum DrillState {
  stopped,
  waiting,
  showing,
}

class HistoryItem {
  final String activityType;
  final DateTime dateTime;
  final Map<String, dynamic> details;

  HistoryItem({
    required this.activityType,
    required this.dateTime,
    required this.details,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      activityType: json['activityType'],
      dateTime: DateTime.parse(json['dateTime']),
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() => {
        'activityType': activityType,
        'dateTime': dateTime.toIso8601String(),
        'details': details,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItem &&
          runtimeType == other.runtimeType &&
          dateTime == other.dateTime &&
          activityType == other.activityType;

  @override
  int get hashCode => dateTime.hashCode ^ activityType.hashCode;
}
