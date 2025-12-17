import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitbillapp/core/config/supabase_config.dart';
import 'package:splitbillapp/core/enums/bill_enums.dart';
import 'package:splitbillapp/core/services/storage_service.dart';
import 'package:splitbillapp/features/bills/models/models.dart';
import 'package:splitbillapp/features/bills/providers/bill_providers.dart';

class BillDetailPage extends ConsumerStatefulWidget {
  final String billId;

  const BillDetailPage({super.key, required this.billId});

  @override
  ConsumerState<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends ConsumerState<BillDetailPage> {
  bool _isLoading = false;

  Future<void> _finalizeBill(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize Bill'),
        content: const Text(
          'Are you sure you want to finalize this bill? This will lock the bill and notify all participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        final billService = ref.read(billServiceProvider);
        await billService.finalizeBill(widget.billId);

        if (mounted) {
          // Refresh data
          ref.invalidate(billDetailProvider(widget.billId));

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill finalized successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to finalize bill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _editBill(Bill bill) async {
    final titleController = TextEditingController(text: bill.title);
    final taxController = TextEditingController(
      text: bill.taxPercent.toString(),
    );
    final serviceController = TextEditingController(
      text: bill.servicePercent.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bill Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Bill Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: taxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tax (%)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: serviceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Service (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await SupabaseConfig.client
            .from('bills')
            .update({
              'title': titleController.text.trim(),
              'tax_percent': double.parse(taxController.text),
              'service_percent': double.parse(serviceController.text),
            })
            .eq('id', bill.id);

        ref.invalidate(billDetailProvider(bill.id));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBill(String billId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text('Are you sure you want to delete this bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await SupabaseConfig.client.from('bills').delete().eq('id', billId);

        if (mounted) {
          Navigator.pop(context); // balik ke list bill
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete bill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _addItem(Bill bill) async {
    // Get bill members to know participants
    final membersAsync = ref.read(billMembersProvider(bill.id));
    final members = membersAsync.when(
      data: (data) => data,
      loading: () => <BillMember>[],
      error: (_, __) => <BillMember>[],
    );

    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No participants found. Please add members first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final participantIds = members.map((m) => m.userId).toList();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddItemDialog(
        participantIds: participantIds,
      ),
    );

    if (result != null && mounted) {
      try {
        final billService = ref.read(billServiceProvider);

        // Create new item
        final newItem = await billService.createBillItem(
          billId: bill.id,
          name: result['name'],
          price: result['price'],
          quantity: result['quantity'],
        );

        // Insert assignments
        final userQuantities = result['userQuantities'] as Map<String, double>;
        final assignmentsData = userQuantities.entries
            .where((entry) => entry.value > 0)
            .map(
              (entry) => {
                'item_id': newItem.id,
                'user_id': entry.key,
                'quantity': entry.value,
              },
            )
            .toList();

        if (assignmentsData.isNotEmpty) {
          await SupabaseConfig.client
              .from('item_assignments')
              .insert(assignmentsData);
        }

        // Recalculate all member totals after adding item
        await billService.recalculateBillMemberTotals(bill.id);

        ref.invalidate(billItemsProvider(bill.id));
        ref.invalidate(billMembersProvider(bill.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(billDetailProvider(widget.billId));
    final membersAsync = ref.watch(billMembersProvider(widget.billId));
    final itemsAsync = ref.watch(billItemsProvider(widget.billId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              final bill = billAsync.value;
              if (bill == null) return;

              if (value == 'edit') {
                await _editBill(bill);
              }

              if (value == 'delete') {
                await _deleteBill(bill.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Bill'),
                  ],
                ),
              ),

              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Bill'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // Add FAB for adding items when bill is DRAFT and user is host
      floatingActionButton: billAsync.value != null &&
              billAsync.value!.status == BillStatus.draft &&
              billAsync.value!.createdBy ==
                  SupabaseConfig.client.auth.currentUser?.id
          ? FloatingActionButton.extended(
              onPressed: () => _addItem(billAsync.value!),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            )
          : null,

      body: billAsync.when(
        data: (bill) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(billDetailProvider(widget.billId));
            ref.invalidate(billMembersProvider(widget.billId));
            ref.invalidate(billItemsProvider(widget.billId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Bill Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              bill.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _StatusBadge(status: bill.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(bill.date),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items Section
              const Text(
                'Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No items added yet')),
                      ),
                    );
                  }

                  final subtotal = items.fold<double>(
                    0,
                    (sum, item) => sum + (item.price * item.quantity),
                  );
                  final tax = subtotal * (bill.taxPercent / 100);
                  final service = subtotal * (bill.servicePercent / 100);
                  final total = subtotal + tax + service;

                  return Column(
                    children: [
                      ...items.map(
                        (item) => _ItemCard(
                          item: item,
                          billId: widget.billId,
                          billStatus: bill.status,
                          isHost: bill.createdBy ==
                              SupabaseConfig.client.auth.currentUser?.id,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Summary
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _SummaryRow('Subtotal', subtotal),
                              if (bill.taxPercent > 0)
                                _SummaryRow('Tax (${bill.taxPercent}%)', tax),
                              if (bill.servicePercent > 0)
                                _SummaryRow(
                                  'Service (${bill.servicePercent}%)',
                                  service,
                                ),
                              const Divider(height: 24),
                              _SummaryRow('Total', total, isBold: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading items: $error'),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Members Section
              const Text(
                'Payment Split',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No participants')),
                      ),
                    );
                  }

                  return Column(
                    children: members
                        .map((member) => _MemberCard(
                              member: member,
                              billStatus: bill.status,
                            ))
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading members: $error'),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Finalize Button (only for creator when status is DRAFT)
              if (bill.createdBy ==
                      ref.read(billServiceProvider).currentUserId &&
                  bill.status == BillStatus.draft)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _finalizeBill(bill),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isLoading ? 'Finalizing...' : 'Finalize Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final BillStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case BillStatus.draft:
        color = Colors.orange;
        break;
      case BillStatus.final_:
        color = Colors.blue;
        break;
      case BillStatus.completed:
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.value.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final BillItem item;
  final String billId;
  final BillStatus billStatus;
  final bool isHost;

  const _ItemCard({
    required this.item,
    required this.billId,
    required this.billStatus,
    required this.isHost,
  });

  Future<void> _editItem(BuildContext context, WidgetRef ref) async {
    // Get current assignments for this item
    final assignmentsAsync = ref.read(itemAssignmentsProvider(item.id));
    final assignments = assignmentsAsync.when(
      data: (data) => data,
      loading: () => <ItemAssignment>[],
      error: (_, __) => <ItemAssignment>[],
    );

    // Get bill members to know participants
    final membersAsync = ref.read(billMembersProvider(billId));
    final members = membersAsync.when(
      data: (data) => data,
      loading: () => <BillMember>[],
      error: (_, __) => <BillMember>[],
    );

    final participantIds = members.map((m) => m.userId).toList();

    // Build user quantities map from assignments
    final userQuantities = <String, double>{};
    for (final assignment in assignments) {
      userQuantities[assignment.userId] =
          (userQuantities[assignment.userId] ?? 0.0) + assignment.quantity;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditItemDialog(
        item: item,
        participantIds: participantIds,
        userQuantities: userQuantities,
      ),
    );

    if (result != null && context.mounted) {
      try {
        final billService = ref.read(billServiceProvider);

        // Update item
        await billService.updateBillItem(
          itemId: item.id,
          name: result['name'],
          price: result['price'],
          quantity: result['quantity'],
        );

        // Update assignments - delete old and insert new
        final newUserQuantities = result['userQuantities'] as Map<String, double>;

        // Delete old assignments
        await SupabaseConfig.client
            .from('item_assignments')
            .delete()
            .eq('item_id', item.id);

        // Insert new assignments
        final assignmentsData = newUserQuantities.entries
            .where((entry) => entry.value > 0)
            .map(
              (entry) => {
                'item_id': item.id,
                'user_id': entry.key,
                'quantity': entry.value,
              },
            )
            .toList();

        if (assignmentsData.isNotEmpty) {
          await SupabaseConfig.client
              .from('item_assignments')
              .insert(assignmentsData);
        }

        // Recalculate all member totals after updating item
        await billService.recalculateBillMemberTotals(billId);

        ref.invalidate(billItemsProvider(billId));
        ref.invalidate(itemAssignmentsProvider(item.id));
        ref.invalidate(billMembersProvider(billId)); // Refresh members to show new totals

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final billService = ref.read(billServiceProvider);
        await billService.deleteBillItem(item.id);

        // Recalculate all member totals after deleting item
        await billService.recalculateBillMemberTotals(billId);

        ref.invalidate(billItemsProvider(billId));
        ref.invalidate(billMembersProvider(billId)); // Refresh members to show new totals

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(itemAssignmentsProvider(item.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rp ${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Edit & Delete buttons (only for DRAFT status and host)
                    if (billStatus == BillStatus.draft && isHost) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _editItem(context, ref),
                        tooltip: 'Edit item',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _deleteItem(context, ref),
                        tooltip: 'Delete item',
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.quantity} x Rp ${item.price.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            assignmentsAsync.when(
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Group assignments by user_id and sum quantities
                final userMap = <String, Map<String, dynamic>>{};
                for (final assignment in assignments) {
                  if (userMap.containsKey(assignment.userId)) {
                    userMap[assignment.userId]!['quantity'] +=
                        assignment.quantity;
                  } else {
                    userMap[assignment.userId] = {
                      'quantity': assignment.quantity,
                      'profile': assignment.userProfile,
                    };
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 16),
                    Text(
                      'Split between:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...userMap.entries.map((entry) {
                      final userQty = (entry.value['quantity'] as num).toDouble();
                      final profile = entry.value['profile'] as Profile?;
                      final name =
                          profile?.fullName ??
                          profile?.email?.split('@')[0] ??
                          'User';
                      final userCost = item.price * userQty;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blue,
                              backgroundImage: profile?.avatarUrl != null
                                  ? NetworkImage(profile!.avatarUrl!)
                                  : null,
                              child: profile?.avatarUrl == null
                                  ? Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Split',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rp ${userCost.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerStatefulWidget {
  final BillMember member;
  final BillStatus billStatus;

  const _MemberCard({
    required this.member,
    required this.billStatus,
  });

  @override
  ConsumerState<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends ConsumerState<_MemberCard> {
  bool _isLoading = false;

  Future<void> _confirmPayment(String billId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final currentUserId = ref.read(billServiceProvider).currentUserId;
      if (currentUserId == null) throw Exception('User not logged in');

      // Upload proof to storage
      final proofUrl = await StorageService.uploadPaymentProof(
        File(pickedFile.path),
        currentUserId,
        billId,
      );

      // Update bill member with proof URL
      await ref
          .read(billServiceProvider)
          .confirmPayment(billId: billId, proofUrl: proofUrl);

      if (mounted) {
        // Refresh data
        ref.invalidate(billMembersProvider(billId));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload proof: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _viewPaymentProof(String? proofUrl) {
    if (proofUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Proof'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: InteractiveViewer(
                child: Image.network(
                  proofUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          SizedBox(height: 8),
                          Text('Failed to load image'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.member.userProfile?.fullName ??
        widget.member.userProfile?.email?.split('@')[0] ??
        'Unknown User';

    final currentUserId = ref.read(billServiceProvider).currentUserId;
    final isCurrentUser = widget.member.userId == currentUserId;

    Color statusColor;
    String statusText;
    switch (widget.member.status) {
      case PaymentStatus.unpaid:
        statusColor = Colors.red;
        statusText = 'Unpaid';
        break;
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      case PaymentStatus.paid:
        statusColor = Colors.green;
        statusText = 'Paid';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  backgroundImage: widget.member.userProfile?.avatarUrl != null
                      ? NetworkImage(widget.member.userProfile!.avatarUrl!)
                      : null,
                  child: widget.member.userProfile?.avatarUrl == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (widget.member.userProfile?.email != null)
                        Text(
                          widget.member.userProfile!.email!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${widget.member.finalTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Show confirm payment button for current user if unpaid and bill is finalized
            if (isCurrentUser &&
                widget.member.status == PaymentStatus.unpaid &&
                widget.billStatus == BillStatus.final_) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _confirmPayment(widget.member.billId),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_file, size: 18),
                  label: Text(_isLoading ? 'Uploading...' : 'Confirm Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],

            // Show view proof button if proof exists
            if (widget.member.proofUrl != null &&
                widget.member.proofUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _viewPaymentProof(widget.member.proofUrl),
                icon: const Icon(Icons.image, size: 16),
                label: const Text('View Payment Proof'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _SummaryRow(this.label, this.amount, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Rp ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// Edit Item Dialog
class _EditItemDialog extends StatefulWidget {
  final BillItem item;
  final List<String> participantIds;
  final Map<String, double> userQuantities; // Comes from item_assignments

  const _EditItemDialog({
    required this.item,
    required this.participantIds,
    required this.userQuantities,
  });

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late Map<String, TextEditingController> _userQuantityControllers;
  late Map<String, double> _userQuantities;
  Map<String, Profile> _profiles = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _priceController = TextEditingController(
      text: widget.item.price.toStringAsFixed(0),
    );

    _userQuantities = {};
    _userQuantityControllers = {};
    for (var userId in widget.participantIds) {
      final qty = widget.userQuantities[userId] ?? 0;
      _userQuantities[userId] = qty.toDouble();
      _userQuantityControllers[userId] = TextEditingController(
        text: qty.toString(),
      );
    }

    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .inFilter('id', widget.participantIds);

      final profiles = (response as List)
          .map((json) => Profile.fromJson(json))
          .toList();
      if (mounted) {
        setState(() {
          _profiles = {for (var p in profiles) p.id: p};
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    for (var controller in _userQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _distributeEqually() {
    final totalQty = double.tryParse(_quantityController.text) ?? 0;
    if (totalQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid total quantity first'),
        ),
      );
      return;
    }

    final userCount = widget.participantIds.length;
    final qtyPerUser = (totalQty / userCount).floorToDouble();
    final remainder = totalQty - (qtyPerUser * userCount);

    setState(() {
      for (int i = 0; i < widget.participantIds.length; i++) {
        final userId = widget.participantIds[i];
        final qty = qtyPerUser + (i < remainder ? 1.0 : 0.0);
        _userQuantityControllers[userId]!.text = qty.toStringAsFixed(0);
        _userQuantities[userId] = qty;
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (var userId in widget.participantIds) {
        _userQuantityControllers[userId]!.text = '0';
        _userQuantities[userId] = 0.0;
      }
    });
  }

  double _getTotalAssigned() {
    return _userQuantities.values.fold(0, (sum, qty) => sum + qty);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g., Nasi Goreng',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(),
                          prefixText: 'Rp ',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quantity per person:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Assigned: ${_getTotalAssigned().toStringAsFixed(0)} / ${_quantityController.text}',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  (_getTotalAssigned() -
                                      (double.tryParse(_quantityController.text) ??
                                          0)).abs() < 0.01
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _distributeEqually,
                          icon: const Icon(Icons.people, size: 16),
                          label: const Text(
                            'Split',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...widget.participantIds.map((userId) {
                  final profile = _profiles[userId];
                  final name =
                      profile?.fullName ??
                      profile?.email?.split('@')[0] ??
                      'User';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          backgroundImage: profile?.avatarUrl != null
                              ? NetworkImage(profile!.avatarUrl!)
                              : null,
                          child: profile?.avatarUrl == null
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _userQuantityControllers[userId],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (value) {
                              setState(() {
                                _userQuantities[userId] =
                                    double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final totalQty = double.parse(_quantityController.text);
              final assignedQty = _getTotalAssigned();

              if ((assignedQty - totalQty).abs() > 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Total assigned (${assignedQty.toStringAsFixed(0)}) must equal total quantity (${totalQty.toStringAsFixed(0)})',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'price': double.parse(_priceController.text),
                'quantity': totalQty,
                'userQuantities': _userQuantities,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final List<String> participantIds;

  const _AddItemDialog({
    required this.participantIds,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final Map<String, TextEditingController> _userQuantityControllers = {};
  final Map<String, double> _userQuantities = {};
  final Map<String, Profile?> _profiles = {};
  bool _isLoadingProfiles = true;

  @override
  void initState() {
    super.initState();
    for (final userId in widget.participantIds) {
      _userQuantityControllers[userId] = TextEditingController(text: '0');
      _userQuantities[userId] = 0.0;
    }
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .inFilter('id', widget.participantIds);

      for (final data in response) {
        final profile = Profile.fromJson(data);
        _profiles[profile.id] = profile;
      }
    } catch (e) {
      // Ignore, will show emails/user IDs
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    for (final controller in _userQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _getTotalAssigned() {
    return _userQuantities.values.fold(0, (sum, qty) => sum + qty);
  }

  void _distributeEqually() {
    final total = double.tryParse(_quantityController.text) ?? 0;
    if (total == 0) return;

    final participantCount = widget.participantIds.length;
    final baseQty = (total / participantCount).floorToDouble();
    final remainder = total - (baseQty * participantCount);

    setState(() {
      for (var i = 0; i < widget.participantIds.length; i++) {
        final userId = widget.participantIds[i];
        final qty = baseQty + (i < remainder ? 1.0 : 0.0);
        _userQuantities[userId] = qty;
        _userQuantityControllers[userId]!.text = qty.toStringAsFixed(0);
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final userId in widget.participantIds) {
        _userQuantities[userId] = 0.0;
        _userQuantityControllers[userId]!.text = '0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = double.tryParse(_quantityController.text) ?? 0;
    final assignedQty = _getTotalAssigned();
    final isValid = (assignedQty - totalQty).abs() < 0.01 && totalQty > 0;

    return AlertDialog(
      title: const Text('Add Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (per item)',
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter price';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Total Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {}); // Update UI
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final qty = double.tryParse(value);
                  if (qty == null || qty <= 0) {
                    return 'Please enter valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assign to participants:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${assignedQty.toStringAsFixed(0)} / ${totalQty.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isValid ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              if (_isLoadingProfiles)
                const Center(child: CircularProgressIndicator()),
              if (!_isLoadingProfiles) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _distributeEqually,
                          icon: const Icon(Icons.people, size: 16),
                          label: const Text(
                            'Split',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...widget.participantIds.map((userId) {
                  final profile = _profiles[userId];
                  final name =
                      profile?.fullName ??
                      profile?.email?.split('@')[0] ??
                      'User';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          backgroundImage: profile?.avatarUrl != null
                              ? NetworkImage(profile!.avatarUrl!)
                              : null,
                          child: profile?.avatarUrl == null
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _userQuantityControllers[userId],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (value) {
                              setState(() {
                                _userQuantities[userId] =
                                    double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final totalQty = double.parse(_quantityController.text);
              final assignedQty = _getTotalAssigned();

              if ((assignedQty - totalQty).abs() > 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Total assigned (${assignedQty.toStringAsFixed(0)}) must equal total quantity (${totalQty.toStringAsFixed(0)})',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'price': double.parse(_priceController.text),
                'quantity': totalQty,
                'userQuantities': _userQuantities,
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
