import 'package:splitbillapp/features/bills/models/profile.dart';

class ItemAssignment {
  final String id;
  final String itemId;
  final String userId;
  final double quantity; // Quantity assigned to this user
  final DateTime assignedAt;
  
  // Optional: Populated via join/eager loading
  final Profile? userProfile;

  ItemAssignment({
    required this.id,
    required this.itemId,
    required this.userId,
    required this.quantity,
    required this.assignedAt,
    this.userProfile,
  });

  factory ItemAssignment.fromJson(Map<String, dynamic> json) {
    return ItemAssignment(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      userId: json['user_id'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0, // Default to 1.0 for backward compatibility
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      userProfile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_id': itemId,
      'user_id': userId,
      'quantity': quantity,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }

  ItemAssignment copyWith({
    String? id,
    String? itemId,
    String? userId,
    double? quantity,
    DateTime? assignedAt,
    Profile? userProfile,
  }) {
    return ItemAssignment(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      userId: userId ?? this.userId,
      quantity: quantity ?? this.quantity,
      assignedAt: assignedAt ?? this.assignedAt,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}
