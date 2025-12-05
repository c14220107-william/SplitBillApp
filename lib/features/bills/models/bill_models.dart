enum BillStatus {
  draft('DRAFT'),
  final_('FINAL'),
  completed('COMPLETED');

  final String value;
  const BillStatus(this.value);

  static BillStatus fromString(String value) {
    return BillStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BillStatus.draft,
    );
  }
}

enum PaymentStatus {
  unpaid('UNPAID'),
  pending('PENDING'),
  paid('PAID');

  final String value;
  const PaymentStatus(this.value);

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentStatus.unpaid,
    );
  }
}

class Bill {
  final String id;
  final String createdBy;
  final String title;
  final DateTime date;
  final double taxPercent;
  final double servicePercent;
  final BillStatus status;
  final DateTime createdAt;

  Bill({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.date,
    this.taxPercent = 0,
    this.servicePercent = 0,
    this.status = BillStatus.draft,
    required this.createdAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      taxPercent: (json['tax_percent'] as num?)?.toDouble() ?? 0,
      servicePercent: (json['service_percent'] as num?)?.toDouble() ?? 0,
      status: BillStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_by': createdBy,
      'title': title,
      'date': date.toIso8601String().split('T')[0],
      'tax_percent': taxPercent,
      'service_percent': servicePercent,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
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
    );
  }
}

class BillMember {
  final String id;
  final String billId;
  final String userId;
  final double finalTotal;
  final PaymentStatus status;
  final String? proofUrl;
  final DateTime joinedAt;

  BillMember({
    required this.id,
    required this.billId,
    required this.userId,
    this.finalTotal = 0,
    this.status = PaymentStatus.unpaid,
    this.proofUrl,
    required this.joinedAt,
  });

  factory BillMember.fromJson(Map<String, dynamic> json) {
    return BillMember(
      id: json['id'] as String,
      billId: json['bill_id'] as String,
      userId: json['user_id'] as String,
      finalTotal: (json['final_total'] as num?)?.toDouble() ?? 0,
      status: PaymentStatus.fromString(json['status'] as String),
      proofUrl: json['proof_url'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
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
  }) {
    return BillMember(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      userId: userId ?? this.userId,
      finalTotal: finalTotal ?? this.finalTotal,
      status: status ?? this.status,
      proofUrl: proofUrl ?? this.proofUrl,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class BillItem {
  final String id;
  final String billId;
  final String name;
  final double price;
  final int quantity;
  final DateTime createdAt;

  BillItem({
    required this.id,
    required this.billId,
    required this.name,
    required this.price,
    this.quantity = 1,
    required this.createdAt,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] as String,
      billId: json['bill_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
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
    };
  }

  double get total => price * quantity;

  BillItem copyWith({
    String? id,
    String? billId,
    String? name,
    double? price,
    int? quantity,
    DateTime? createdAt,
  }) {
    return BillItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ItemAssignment {
  final String id;
  final String itemId;
  final String userId;
  final DateTime assignedAt;

  ItemAssignment({
    required this.id,
    required this.itemId,
    required this.userId,
    required this.assignedAt,
  });

  factory ItemAssignment.fromJson(Map<String, dynamic> json) {
    return ItemAssignment(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      userId: json['user_id'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_id': itemId,
      'user_id': userId,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }
}
