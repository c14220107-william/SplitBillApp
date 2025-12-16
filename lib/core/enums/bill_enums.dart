// Enums for bill and payment status
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
