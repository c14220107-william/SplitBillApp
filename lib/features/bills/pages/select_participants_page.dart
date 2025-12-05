import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitbillapp/core/config/supabase_config.dart';
import 'package:splitbillapp/features/bills/models/models.dart';
import 'package:splitbillapp/features/bills/providers/bill_providers.dart';

// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider for selected user IDs
final selectedUserIdsProvider = StateProvider<Set<String>>((ref) => {});

// Provider for searching users - load all users initially
final searchUsersProvider = FutureProvider<List<Profile>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final billService = ref.watch(billServiceProvider);
  
  if (query.isEmpty) {
    // Load all users when no search query
    final response = await SupabaseConfig.client
        .from('profiles')
        .select()
        .limit(50);
    return (response as List).map((json) => Profile.fromJson(json)).toList();
  }
  
  return billService.searchUsers(query);
});

class SelectParticipantsPage extends ConsumerStatefulWidget {
  const SelectParticipantsPage({super.key});

  @override
  ConsumerState<SelectParticipantsPage> createState() => _SelectParticipantsPageState();
}

class _SelectParticipantsPageState extends ConsumerState<SelectParticipantsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmSelection() {
    final selectedIds = ref.read(selectedUserIdsProvider);
    context.pop(selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchUsersProvider);
    final selectedIds = ref.watch(selectedUserIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Participants'),
        actions: [
          TextButton(
            onPressed: selectedIds.isEmpty ? null : _confirmSelection,
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by email or name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Selected Count
          if (selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedIds.length} participant(s) selected',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Search Results
          Expanded(
            child: searchResults.when(
              data: (users) {
                // Always show users list if available
                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = selectedIds.contains(user.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        if (value == true) {
                          ref.read(selectedUserIdsProvider.notifier).state = 
                              {...selectedIds, user.id};
                        } else {
                          ref.read(selectedUserIdsProvider.notifier).state = 
                              selectedIds.where((id) => id != user.id).toSet();
                        }
                      },
                      title: Text(user.fullName ?? user.email ?? 'Unknown'),
                      subtitle: user.fullName != null ? Text(user.email ?? '') : null,
                      secondary: CircleAvatar(
                        backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                        child: user.avatarUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      color: isSelected ? Colors.white : Colors.grey[600],
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: isSelected ? Colors.white : Colors.grey[600],
                              ),
                      ),
                    );
                  },
                );
              },
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
          ),
        ],
      ),
    );
  }
}
