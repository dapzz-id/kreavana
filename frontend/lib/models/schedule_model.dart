class CreatorCapacitySchedule {
  final String id;
  final String creatorId;
  final String date;
  final int? maxCapacity;
  final bool isUnavailable;
  final String? notes;

  CreatorCapacitySchedule({
    required this.id,
    required this.creatorId,
    required this.date,
    this.maxCapacity,
    this.isUnavailable = false,
    this.notes,
  });

  factory CreatorCapacitySchedule.fromJson(Map<String, dynamic> json) {
    return CreatorCapacitySchedule(
      id: json['id']?.toString() ?? '',
      creatorId: json['creator_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      maxCapacity: json['max_capacity'] != null
          ? int.tryParse(json['max_capacity'].toString())
          : null,
      isUnavailable:
          json['is_unavailable'] == true ||
          json['is_unavailable'] == 1 ||
          json['is_unavailable'] == '1',
      notes: json['notes']?.toString(),
    );
  }
}

class AvailabilityDay {
  final String date;
  final bool isWorkingDay;
  final String availabilityStatus;

  AvailabilityDay({
    required this.date,
    required this.isWorkingDay,
    required this.availabilityStatus,
  });

  factory AvailabilityDay.fromJson(Map<String, dynamic> json) {
    return AvailabilityDay(
      date: json['date']?.toString() ?? '',
      isWorkingDay:
          json['is_working_day'] == true ||
          json['is_working_day'] == 1 ||
          json['is_working_day'] == '1',
      availabilityStatus: json['availability_status']?.toString() ?? 'Unknown',
    );
  }
}

class AvailabilityConflict {
  final String date;
  final String reason;
  final int remainingCapacity;

  AvailabilityConflict({
    required this.date,
    required this.reason,
    required this.remainingCapacity,
  });

  factory AvailabilityConflict.fromJson(Map<String, dynamic> json) {
    return AvailabilityConflict(
      date: json['date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      remainingCapacity: json['remaining_capacity'] != null
          ? int.tryParse(json['remaining_capacity'].toString()) ?? 0
          : 0,
    );
  }
}

class AvailabilityRange {
  final bool available;
  final int workingDays;
  final int unavailableDays;
  final List<AvailabilityDay> days;
  final List<AvailabilityConflict>? conflicts;

  AvailabilityRange({
    required this.available,
    required this.workingDays,
    required this.unavailableDays,
    required this.days,
    this.conflicts,
  });

  factory AvailabilityRange.fromJson(Map<String, dynamic> json) {
    return AvailabilityRange(
      available:
          json['available'] == true ||
          json['available'] == 1 ||
          json['available'] == '1',
      workingDays: json['working_days'] != null
          ? int.tryParse(json['working_days'].toString()) ?? 0
          : 0,
      unavailableDays: json['unavailable_days'] != null
          ? int.tryParse(json['unavailable_days'].toString()) ?? 0
          : 0,
      days: json['days'] != null
          ? (json['days'] as List)
                .map((e) => AvailabilityDay.fromJson(e))
                .toList()
          : [],
      conflicts: json['conflicts'] != null
          ? (json['conflicts'] as List)
                .map((e) => AvailabilityConflict.fromJson(e))
                .toList()
          : null,
    );
  }
}

class AvailabilityDetail {
  final String date;
  final bool isWorkingDay;
  final int? effectiveCapacity;
  final int activeWorkCount;
  final int bookingCount;
  final int usedCapacity;
  final int? remainingCapacity;
  final String availabilityStatus;
  final String? notes;

  AvailabilityDetail({
    required this.date,
    required this.isWorkingDay,
    this.effectiveCapacity,
    required this.activeWorkCount,
    required this.bookingCount,
    required this.usedCapacity,
    this.remainingCapacity,
    required this.availabilityStatus,
    this.notes,
  });

  factory AvailabilityDetail.fromJson(Map<String, dynamic> json) {
    return AvailabilityDetail(
      date: json['date']?.toString() ?? '',
      isWorkingDay:
          json['is_working_day'] == true ||
          json['is_working_day'] == 1 ||
          json['is_working_day'] == '1',
      effectiveCapacity: json['effective_capacity'] != null
          ? int.tryParse(json['effective_capacity'].toString())
          : null,
      activeWorkCount: json['active_work_count'] != null
          ? int.tryParse(json['active_work_count'].toString()) ?? 0
          : 0,
      bookingCount: json['booking_count'] != null
          ? int.tryParse(json['booking_count'].toString()) ?? 0
          : 0,
      usedCapacity: json['used_capacity'] != null
          ? int.tryParse(json['used_capacity'].toString()) ?? 0
          : 0,
      remainingCapacity: json['remaining_capacity'] != null
          ? int.tryParse(json['remaining_capacity'].toString())
          : null,
      availabilityStatus: json['availability_status']?.toString() ?? 'Unknown',
      notes: json['notes']?.toString(),
    );
  }
}
