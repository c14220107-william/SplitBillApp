import 'package:splitbillapp/core/enums/bill_enums.dart';
import 'package:splitbillapp/features/bills/models/profile.dart';

class BillMember {
  final String id;
  final String billId;
  final String userId;
  final double finalTotal;
  final PaymentStatus status;
  final String? proofUrl;
  final DateTime joinedAt;
  final DateTime updatedAt;
  
  // Optional: Populated via join/eager loading
  final Profile? userProfile;

  BillMember({
    required this.id,
    required this.billId,
    required this.userId,
    this.finalTotal = 0,
    this.status = PaymentStatus.unpaid,
    this.proofUrl,
    required this.joinedAt,
    required this.updatedAt,
    this.userProfile,
  });

  factory BillMember.fromJson(Map<String, dynamic> json) {
    return BillMember(
      id: json['id'] as String,
      billId: json['bill_id'] as String,
      userId: json['user_id'] as String,
      finalTotal: (json['final_total'] as num?)?.toDouble() ?? 0,
      status: json['status'] != null
          ? PaymentStatus.fromString(json['status'] as String)
          : PaymentStatus.unpaid,
      proofUrl: json['proof_url'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['joined_at'] as String), // Use joined_at if updated_at is null
      userProfile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'user_id': userId,
      'final_total': finalTotal,
      'status': status.value,
      'proof_url': proofUrl,
      'joined_at': joinedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BillMember copyWith({
    String? id,
    String? billId,
    String? userId,
    double? finalTotal,
    PaymentStatus? status,
    String? proofUrl,
    DateTime? joinedAt,
    DateTime? updatedAt,
    Profile? userProfile,
  }) {
    return BillMember(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      userId: userId ?? this.userId,
      finalTotal: finalTotal ?? this.finalTotal,
      status: status ?? this.status,
      proofUrl: proofUrl ?? this.proofUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}
