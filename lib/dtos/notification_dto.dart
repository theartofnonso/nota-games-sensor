import 'package:trainware/extensions/datetime/datetime_extension.dart';

class NotificationDto {
  final DateTime dateTime;

  NotificationDto({required this.dateTime});

  Map<String, dynamic> toJson() {
    return {
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    final dateTimeString = json["dateTime"];
    final now = DateTime.now().withoutTime();
    DateTime dateTime = dateTimeString != null
        ? DateTime.parse(dateTimeString).withoutTime()
        : now;
    if (dateTime.isBefore(now)) {
      dateTime = now;
    }
    return NotificationDto(dateTime: dateTime);
  }

  @override
  String toString() {
    return 'NotificationDto{dateTime: $dateTime}';
  }
}
