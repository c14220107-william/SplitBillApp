import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitbillapp/core/config/supabase_config.dart';
import 'package:splitbillapp/features/bills/models/models.dart';
import 'package:splitbillapp/features/bills/providers/bill_providers.dart';

// Temporary item data class
class TempBillItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final Map<String, double> userQuantities; // userId -> quantity per user

  TempBillItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.userQuantities,
  });

  double get totalPrice => quantity * price;
  double get pricePerItem => price;
  
  List<String> get assignedUserIds => userQuantities.keys.toList();
  double get totalAssignedQuantity => userQuantities.values.fold(0.0, (sum, qty) => sum + qty);
  
  double getUserTotal(String userId) {
    final userQty = userQuantities[userId] ?? 0.0;
    return userQty * price;
  }
}

// State provider for temporary items
final tempItemsProvider = StateProvider<List<TempBillItem>>((ref) => []);

class AddItemsPage extends ConsumerStatefulWidget {
  final String billTitle;
  final DateTime billDate;
  final double taxPercent;
  final double servicePercent;
  final List<String> participantIds;

  const AddItemsPage({
    super.key,
    required this.billTitle,
    required this.billDate,
    required this.taxPercent,
    required this.servicePercent,
    required this.participantIds,
  });

  @override
  ConsumerState<AddItemsPage> createState() => _AddItemsPageState();
}

class _AddItemsPageState extends ConsumerState<AddItemsPage> {
  bool _isLoading = false;
  Map<String, Profile> _profiles = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    // Clear previous items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tempItemsProvider.notifier).state = [];
    });
  }

  Future<void> _loadProfiles() async {
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .inFilter('id', widget.participantIds);
      
      final profiles = (response as List).map((json) => Profile.fromJson(json)).toList();
      setState(() {
        _profiles = {for (var p in profiles) p.id: p};
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profiles: $e')),
        );
      }
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddItemDialog(participantIds: widget.participantIds, profiles: _profiles),
    );

    if (result != null) {
      final items = ref.read(tempItemsProvider);
      ref.read(tempItemsProvider.notifier).state = [
        ...items,
        TempBillItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name'],
          quantity: result['quantity'],
          price: result['price'],
          userQuantities: result['userQuantities'],
        ),
      ];
    }
  }

  Future<void> _editItem(TempBillItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddItemDialog(
        participantIds: widget.participantIds,
        profiles: _profiles,
        initialItem: item,
      ),
    );

    if (result != null) {
      final items = ref.read(tempItemsProvider);
      ref.read(tempItemsProvider.notifier).state = items.map((i) {
        if (i.id == item.id) {
          return TempBillItem(
            id: i.id,
            name: result['name'],
            quantity: result['quantity'],
            price: result['price'],
            userQuantities: result['userQuantities'],
          );
        }
        return i;
      }).toList();
    }
  }

  void _deleteItem(String itemId) {
    final items = ref.read(tempItemsProvider);
    ref.read(tempItemsProvider.notifier).state = 
        items.where((i) => i.id != itemId).toList();
  }

  Future<void> _createBill() async {
    final items = ref.read(tempItemsProvider);
    
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    // Check all items have assigned users
    final unassignedItems = items.where((i) => i.userQuantities.isEmpty).toList();
    if (unassignedItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please assign users to: ${unassignedItems.map((i) => i.name).join(", ")}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Check quantity matches
    final mismatchedItems = items.where((i) => (i.totalAssignedQuantity - i.quantity).abs() > 0.01).toList();
    if (mismatchedItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quantity mismatch in: ${mismatchedItems.map((i) => i.name).join(", ")}. Please check assigned quantities.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final billService = ref.read(billServiceProvider);
      
      // Convert temp items to format expected by service
      final itemsData = items.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'userQuantities': item.userQuantities,
      }).toList();

      // Create bill with all items
      await billService.createBillWithItems(
        title: widget.billTitle,
        date: widget.billDate,
        taxPercent: widget.taxPercent,
        servicePercent: widget.servicePercent,
        participantIds: widget.participantIds,
        items: itemsData,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill created successfully!'), backgroundColor: Colors.green),
        );
        // Return true to indicate success
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create bill: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculateSubtotal(List<TempBillItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _calculateTotal(double subtotal) {
    final tax = subtotal * (widget.taxPercent / 100);
    final service = subtotal * (widget.servicePercent / 100);
    return subtotal + tax + service;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(tempItemsProvider);
    final subtotal = _calculateSubtotal(items);
    final total = _calculateTotal(subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Items'),
      ),
      body: Column(
        children: [
          // Bill Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.billTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${widget.participantIds.length} participants'),
                  if (items.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text('Rp ${subtotal.toStringAsFixed(0)}'),
                      ],
                    ),
                    if (widget.taxPercent > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tax (${widget.taxPercent}%):'),
                          Text('Rp ${(subtotal * widget.taxPercent / 100).toStringAsFixed(0)}'),
                        ],
                      ),
                    if (widget.servicePercent > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Service (${widget.servicePercent}%):'),
                          Text('Rp ${(subtotal * widget.servicePercent / 100).toStringAsFixed(0)}'),
                        ],
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Rp ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Items List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No items added yet', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text('Tap + to add items', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _editItem(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _deleteItem(item.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${item.quantity} x Rp ${item.price.toStringAsFixed(0)}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Rp ${item.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              // Participants section
                              if (item.userQuantities.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.people, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Split between ${item.userQuantities.length} people:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...item.userQuantities.entries.map((entry) {
                                  final userId = entry.key;
                                  final userQty = entry.value;
                                  final profile = _profiles[userId];
                                  final displayName = profile?.fullName ?? profile?.email?.split('@')[0] ?? 'User';
                                  final userTotal = item.getUserTotal(userId);
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.blue,
                                          child: Text(
                                            displayName[0].toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 11),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                          'Rp ${userTotal.toStringAsFixed(0)}',
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
                              ] else
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                                      const SizedBox(width: 6),
                                      Text(
                                        'No participants assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createBill,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Bill'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog for adding/editing item
class _AddItemDialog extends StatefulWidget {
  final List<String> participantIds;
  final Map<String, Profile> profiles;
  final TempBillItem? initialItem;

  const _AddItemDialog({
    required this.participantIds,
    required this.profiles,
    this.initialItem,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late Map<String, TextEditingController> _userQuantityControllers;
  late Map<String, double> _userQuantities;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialItem?.name ?? '');
    _quantityController = TextEditingController(text: widget.initialItem?.quantity.toString() ?? '1');
    _priceController = TextEditingController(text: widget.initialItem?.price.toString() ?? '');
    
    // Initialize user quantity controllers
    _userQuantities = (widget.initialItem?.userQuantities ?? {}).map(
      (key, value) => MapEntry(key, value.toDouble()),
    );
    _userQuantityControllers = {};
    for (var userId in widget.participantIds) {
      _userQuantityControllers[userId] = TextEditingController(
        text: _userQuantities[userId]?.toString() ?? '0',
      );
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
    final totalQty = int.tryParse(_quantityController.text) ?? 0;
    if (totalQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid total quantity first')),
      );
      return;
    }
    
    // Get users who have quantity > 0 (assigned users)
    final assignedUsers = _userQuantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
    
    // If no users assigned, distribute to all participants
    final usersToDistribute = assignedUsers.isNotEmpty ? assignedUsers : widget.participantIds;
    final userCount = usersToDistribute.length;
    
    if (userCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No participants to distribute to')),
      );
      return;
    }
    
    final qtyPerUser = totalQty / userCount;
    
    setState(() {
      // Reset all to 0 first
      for (var userId in widget.participantIds) {
        _userQuantityControllers[userId]!.text = '0';
        _userQuantities[userId] = 0.0;
      }
      // Set quantity for assigned users
      for (var userId in usersToDistribute) {
        _userQuantityControllers[userId]!.text = qtyPerUser.toStringAsFixed(2);
        _userQuantities[userId] = qtyPerUser;
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (var userId in widget.participantIds) {
        _userQuantityControllers[userId]!.text = '0';
        _userQuantities[userId] = 1.0;
      }
    });
  }

  double _getTotalAssigned() {
    return _userQuantities.values.fold(0.0, (sum, qty) => sum + qty);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialItem == null ? 'Add Item' : 'Edit Item'),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onTap: () {
                          _quantityController.clear();
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final qty = int.tryParse(value);
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          const Text('Quantity per person:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            'Assigned: ${_getTotalAssigned().toStringAsFixed(2)} / ${_quantityController.text}',
                            style: TextStyle(
                              fontSize: 11,
                              color: (_getTotalAssigned() - (int.tryParse(_quantityController.text) ?? 0)).abs() < 0.01
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
                          label: const Text('Split', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear', style: TextStyle(fontSize: 12)),
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
                  final profile = widget.profiles[userId];
                  final name = profile?.fullName ?? profile?.email?.split('@')[0] ?? 'User';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(name, style: const TextStyle(fontSize: 14)),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _userQuantityControllers[userId],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onTap: () {
                              _userQuantityControllers[userId]!.clear();
                            },
                            onChanged: (value) {
                              setState(() {
                                _userQuantities[userId] = double.tryParse(value) ?? 0.0;
                              });
                            },
                            validator: (value) {
                              final qty = double.tryParse(value ?? '');
                              if (qty == null || qty < 0) {
                                return 'Invalid';
                              }
                              return null;
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
              // Filter out users with 0 quantity
              final userQuantities = Map<String, double>.from(_userQuantities);
              userQuantities.removeWhere((key, value) => value == 0);
              
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'quantity': int.parse(_quantityController.text),
                'price': double.parse(_priceController.text),
                'userQuantities': userQuantities,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
