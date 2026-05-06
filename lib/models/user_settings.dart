class UserSettings {
  final int notificationDaysBefore;

  const UserSettings({this.notificationDaysBefore = 7});

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        notificationDaysBefore: json['notification_days_before'] as int? ?? 7,
      );

  Map<String, dynamic> toJson() => {
        'notification_days_before': notificationDaysBefore,
      };
}
