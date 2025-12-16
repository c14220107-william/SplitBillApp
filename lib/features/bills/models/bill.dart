import 'package:splitbillapp/core/enums/bill_enums.dart';

class Bill {
  final String id;
  final String createdBy;
  final String title;
  final DateTime date;
  final double taxPercent;
  final double servicePercent;
  final BillStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bill({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.date,
    this.taxPercent = 0,
    this.servicePercent = 0,
    this.status = BillStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      taxPercent: (json['tax_percent'] as num?)?.toDouble() ?? 0,
      servicePercent: (json['service_percent'] as num?)?.toDouble() ?? 0,
      status: json['status'] != null 
          ? BillStatus.fromString(json['status'] as String)
          : BillStatus.draft,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String), // Use created_at if updated_at is null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_by': createdBy,
      'title': title,
      'date': date.toIso8601String().split('T')[0], // Date only
      'tax_percent': taxPercent,
      'service_percent': servicePercent,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Bill copyWith({
    String? id,
    String? createdBy,
    String? title,
    DateTime? date,
    double? taxPercent,
    double? servicePercent,
    BillStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bill(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      date: date ?? this.date,
      taxPercent: taxPercent ?? this.taxPercent,
      servicePercent: servicePercent ?? this.servicePercent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
