class BillItem {
  final String id;
  final String billId;
  final String name;
  final double price;
  final double quantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Optional: List of user IDs who are assigned to this item
  final List<String>? assignedUserIds;

  BillItem({
    required this.id,
    required this.billId,
    required this.name,
    required this.price,
    this.quantity = 1.0,
    required this.createdAt,
    required this.updatedAt,
    this.assignedUserIds,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] as String,
      billId: json['bill_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String), // Use created_at if updated_at is null
      assignedUserIds: json['assigned_user_ids'] != null
          ? List<String>.from(json['assigned_user_ids'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bill_id': billId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Calculate total price (price * quantity)
  double get totalPrice => price * quantity;

  // Calculate price per person when divided among assigned users
  double pricePerPerson(int numberOfAssignedUsers) {
    if (numberOfAssignedUsers == 0) return 0;
    return totalPrice / numberOfAssignedUsers;
  }

  BillItem copyWith({
    String? id,
    String? billId,
    String? name,
    double? price,
    double? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? assignedUserIds,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
    );
  }
}
