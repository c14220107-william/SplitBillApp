import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:splitbillapp/core/config/supabase_config.dart';
import 'package:splitbillapp/features/bills/models/models.dart';
import 'package:splitbillapp/features/notifications/services/notification_service.dart';

class BillService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final NotificationService _notificationService = NotificationService();

  // Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ==================== BILLS ====================

  /// Get all bills created by current user
  Future<List<Bill>> getMyCreatedBills() async {
    try {
      final response = await _supabase
          .from('bills')
          .select()
          .eq('created_by', currentUserId!)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        try {
          return Bill.fromJson(json);
        } catch (e) {
          print('Error parsing bill: $e');
          print('JSON data: $json');
          rethrow;
        }
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch created bills: $e');
    }
  }

  /// Get all bills where current user is a member (invited to)
  Future<List<Bill>> getMyInvitedBills() async {
    try {
      // First, get bill IDs where user is a member
      final memberResponse = await _supabase
          .from('bill_members')
          .select('bill_id')
          .eq('user_id', currentUserId!);

      final billIds = (memberResponse as List)
          .map((item) => item['bill_id'] as String)
          .toList();

      if (billIds.isEmpty) {
        return [];
      }

      // Then, get the bills (excluding ones created by user)
      final response = await _supabase
          .from('bills')
          .select()
          .inFilter('id', billIds)
          .neq('created_by', currentUserId!)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Bill.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch invited bills: $e');
    }
  }

  /// Get single bill by ID
  Future<Bill> getBillById(String billId) async {
    try {
      final response = await _supabase
          .from('bills')
          .select()
          .eq('id', billId)
          .single();

      return Bill.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch bill: $e');
    }
  }

  /// Create new bill
  Future<Bill> createBill({
    required String title,
    required DateTime date,
    double taxPercent = 0,
    double servicePercent = 0,
  }) async {
    try {
      final response = await _supabase
          .from('bills')
          .insert({
            'created_by': currentUserId!,
            'title': title,
            'date': date.toIso8601String().split('T')[0],
            'tax_percent': taxPercent,
            'service_percent': servicePercent,
          })
          .select()
          .single();

      return Bill.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create bill: $e');
    }
  }

  /// Update bill
  Future<Bill> updateBill({
    required String billId,
    String? title,
    DateTime? date,
    double? taxPercent,
    double? servicePercent,
    String? status,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (date != null) updateData['date'] = date.toIso8601String().split('T')[0];
      if (taxPercent != null) updateData['tax_percent'] = taxPercent;
      if (servicePercent != null) updateData['service_percent'] = servicePercent;
      if (status != null) updateData['status'] = status;

      final response = await _supabase
          .from('bills')
          .update(updateData)
          .eq('id', billId)
          .select()
          .single();

      return Bill.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update bill: $e');
    }
  }

  /// Delete bill
  Future<void> deleteBill(String billId) async {
    try {
      await _supabase.from('bills').delete().eq('id', billId);
    } catch (e) {
      throw Exception('Failed to delete bill: $e');
    }
  }

  /// Finalize bill (change status from DRAFT to FINAL)
  /// Also sends notifications to all invited members
  Future<Bill> finalizeBill(String billId) async {
    try {
      print('🔔 Starting finalize bill: $billId');
      
      // Update bill status
      final response = await _supabase
          .from('bills')
          .update({'status': 'FINAL'})
          .eq('id', billId)
          .eq('created_by', currentUserId!) // Only creator can finalize
          .select()
          .single();

      final bill = Bill.fromJson(response);
      print('✅ Bill status updated to FINAL');

      // Get all members except creator
      final membersResponse = await _supabase
          .from('bill_members')
          .select('user_id')
          .eq('bill_id', billId)
          .neq('user_id', currentUserId!);

      final invitedUserIds = (membersResponse as List)
          .map((m) => m['user_id'] as String)
          .toList();

      print('👥 Found ${invitedUserIds.length} invited users');

      // Send notifications to invited users via NotificationService
      if (invitedUserIds.isNotEmpty) {
        await _notificationService.sendBillFinalizedNotification(
          billId: billId,
          billTitle: bill.title,
          userIds: invitedUserIds,
        );
        print('✅ Notifications sent via NotificationService');
      } else {
        print('⚠️ No invited users to notify');
      }

      return bill;
    } catch (e) {
      print('❌ Error finalizing bill: $e');
      throw Exception('Failed to finalize bill: $e');
    }
  }

  /// Create bill with items and assignments
  Future<Bill> createBillWithItems({
    required String title,
    required DateTime date,
    required double taxPercent,
    required double servicePercent,
    required List<String> participantIds,
    required List<Map<String, dynamic>> items, // {name, quantity, price, userQuantities}
  }) async {
    try {
      // 1. Create bill
      final billResponse = await _supabase
          .from('bills')
          .insert({
            'created_by': currentUserId!,
            'title': title,
            'date': date.toIso8601String().split('T')[0],
            'tax_percent': taxPercent,
            'service_percent': servicePercent,
          })
          .select()
          .single();

      final bill = Bill.fromJson(billResponse);

      // 2. Calculate each user's total before inserting members
      final userTotals = <String, double>{};
      for (final userId in participantIds) {
        userTotals[userId] = 0.0;
      }

      // 3. Add items and calculate user totals based on quantity per user
      for (final item in items) {
        final itemResponse = await _supabase
            .from('bill_items')
            .insert({
              'bill_id': bill.id,
              'name': item['name'] as String,
              'quantity': item['quantity'] as int,
              'price': (item['price'] as num).toDouble(),
            })
            .select()
            .single();

        final itemId = itemResponse['id'] as String;
        final userQuantities = (item['userQuantities'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
        final pricePerItem = (item['price'] as num).toDouble();

        // 4. Add item assignments and calculate cost per user
        if (userQuantities.isNotEmpty) {
          final assignmentInserts = <Map<String, dynamic>>[];
          
          for (final entry in userQuantities.entries) {
            final userId = entry.key;
            final userQty = entry.value;
            
            if (userQty > 0) {
              assignmentInserts.add({
                'item_id': itemId,
                'user_id': userId,
                'quantity': userQty, // Store quantity per user
              });
              
              // Calculate this user's cost for this item
              final userCost = pricePerItem * userQty;
              userTotals[userId] = (userTotals[userId] ?? 0) + userCost;
            }
          }

          if (assignmentInserts.isNotEmpty) {
            await _supabase.from('item_assignments').insert(assignmentInserts);
          }
        }
      }

      // Calculate subtotal
      final subtotal = userTotals.values.fold<double>(0, (sum, amount) => sum + amount);
      final tax = subtotal * (taxPercent / 100);
      final service = subtotal * (servicePercent / 100);
      final grandTotal = subtotal + tax + service;

      // Distribute tax and service proportionally
      final taxServiceRatio = grandTotal / subtotal;

      // 5. Add members with calculated final_total
      final memberInserts = participantIds.map((userId) {
        final userSubtotal = userTotals[userId] ?? 0;
        final userFinalTotal = userSubtotal * taxServiceRatio;
        
        // Host (creator) automatically marked as PAID
        final isHost = userId == currentUserId;
        
        return {
          'bill_id': bill.id,
          'user_id': userId,
          'final_total': userFinalTotal,
          'status': isHost ? 'PAID' : 'UNPAID',
        };
      }).toList();

      await _supabase.from('bill_members').insert(memberInserts);

      // Send invite notifications to participants (except creator)
      final invitedUserIds = participantIds.where((id) => id != currentUserId).toList();
      if (invitedUserIds.isNotEmpty) {
        // Get current user's name
        final userResponse = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', currentUserId!)
            .single();
        final inviterName = userResponse['full_name'] ?? 'Someone';

        await _notificationService.sendBillInviteNotification(
          billId: bill.id,
          billTitle: bill.title,
          inviterName: inviterName,
          userIds: invitedUserIds,
        );
        print('✅ Invite notifications sent to ${invitedUserIds.length} users');
      }

      return bill;
    } catch (e) {
      throw Exception('Failed to create bill with items: $e');
    }
  }

  // ==================== BILL MEMBERS ====================

  /// Get all members of a bill
  Future<List<BillMember>> getBillMembers(String billId) async {
    try {
      final response = await _supabase
          .from('bill_members')
          .select('*, profiles(*)')
          .eq('bill_id', billId);

      return (response as List).map((json) => BillMember.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch bill members: $e');
    }
  }

  /// Add member to bill
  Future<BillMember> addMemberToBill({
    required String billId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('bill_members')
          .insert({
            'bill_id': billId,
            'user_id': userId,
          })
          .select('*, profiles(*)')
          .single();

      return BillMember.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  /// Update member payment status
  Future<BillMember> updateMemberPayment({
    required String memberId,
    required String status,
    double? finalTotal,
    String? proofUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': status};
      if (finalTotal != null) updateData['final_total'] = finalTotal;
      if (proofUrl != null) updateData['proof_url'] = proofUrl;

      final response = await _supabase
          .from('bill_members')
          .update(updateData)
          .eq('id', memberId)
          .select('*, profiles(*)')
          .single();

      return BillMember.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update member payment: $e');
    }
  }

  // ==================== BILL ITEMS ====================

  /// Get all items in a bill
  Future<List<BillItem>> getBillItems(String billId) async {
    try {
      final response = await _supabase
          .from('bill_items')
          .select()
          .eq('bill_id', billId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => BillItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch bill items: $e');
    }
  }

  /// Create new item
  Future<BillItem> createBillItem({
    required String billId,
    required String name,
    required double price,
    int quantity = 1,
  }) async {
    try {
      final response = await _supabase
          .from('bill_items')
          .insert({
            'bill_id': billId,
            'name': name,
            'price': price,
            'quantity': quantity,
          })
          .select()
          .single();

      return BillItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create item: $e');
    }
  }

  /// Update item
  Future<BillItem> updateBillItem({
    required String itemId,
    String? name,
    double? price,
    int? quantity,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (price != null) updateData['price'] = price;
      if (quantity != null) updateData['quantity'] = quantity;

      final response = await _supabase
          .from('bill_items')
          .update(updateData)
          .eq('id', itemId)
          .select()
          .single();

      return BillItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  /// Delete item
  Future<void> deleteBillItem(String itemId) async {
    try {
      await _supabase.from('bill_items').delete().eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  // ==================== ITEM ASSIGNMENTS ====================

  /// Get all assignments for an item
  Future<List<ItemAssignment>> getItemAssignments(String itemId) async {
    try {
      final response = await _supabase
          .from('item_assignments')
          .select('*, profiles(*)')
          .eq('item_id', itemId);

      return (response as List).map((json) => ItemAssignment.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch assignments: $e');
    }
  }

  /// Assign users to an item (batch operation)
  Future<void> assignUsersToItem({
    required String itemId,
    required List<String> userIds,
  }) async {
    try {
      // First, remove existing assignments
      await _supabase.from('item_assignments').delete().eq('item_id', itemId);

      // Then, insert new assignments
      if (userIds.isNotEmpty) {
        final assignments = userIds.map((userId) => {
          'item_id': itemId,
          'user_id': userId,
        }).toList();

        await _supabase.from('item_assignments').insert(assignments);
      }
    } catch (e) {
      throw Exception('Failed to assign users to item: $e');
    }
  }

  // ==================== PROFILES ====================

  /// Search users by email or name
  Future<List<Profile>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .or('email.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);

      return (response as List).map((json) => Profile.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Get user profile by ID
  Future<Profile> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  /// Update current user profile
  Future<Profile> updateMyProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      final response = await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', currentUserId!)
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // ==================== PAYMENT CONFIRMATION ====================

  /// Update payment status with proof URL
  Future<void> confirmPayment({
    required String billId,
    required String proofUrl,
  }) async {
    try {
      await _supabase
          .from('bill_members')
          .update({
            'proof_url': proofUrl,
            'status': 'pending',
          })
          .eq('bill_id', billId)
          .eq('user_id', currentUserId!);
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }
}
