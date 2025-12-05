import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitbillapp/features/bills/models/models.dart';
import 'package:splitbillapp/features/bills/services/bill_service.dart';

// Service Provider
final billServiceProvider = Provider<BillService>((ref) {
  return BillService();
});

// Bills Created by Me
final myCreatedBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getMyCreatedBills();
});

// Bills I'm Invited To
final myInvitedBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getMyInvitedBills();
});

// Single Bill by ID
final billDetailProvider = FutureProvider.family<Bill, String>((ref, billId) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getBillById(billId);
});

// Legacy alias
final billByIdProvider = billDetailProvider;

// Bill Members
final billMembersProvider = FutureProvider.family<List<BillMember>, String>((ref, billId) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getBillMembers(billId);
});

// Bill Items
final billItemsProvider = FutureProvider.family<List<BillItem>, String>((ref, billId) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getBillItems(billId);
});

// Item Assignments
final itemAssignmentsProvider = FutureProvider.family<List<ItemAssignment>, String>((ref, itemId) async {
  final billService = ref.watch(billServiceProvider);
  return billService.getItemAssignments(itemId);
});

// User Search
final userSearchProvider = FutureProvider.family<List<Profile>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final billService = ref.watch(billServiceProvider);
  return billService.searchUsers(query);
});
