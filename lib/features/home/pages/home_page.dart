import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitbillapp/features/bills/models/models.dart';
import 'package:splitbillapp/features/bills/providers/bill_providers.dart';
import 'package:splitbillapp/features/notifications/providers/notification_providers.dart';
import 'package:splitbillapp/core/enums/bill_enums.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Splitbillers'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Created by Me'),
            Tab(text: 'Invited to'),
          ],
        ),
        actions: [
          // Notification Bell
          Consumer(
            builder: (context, ref, child) {
              final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);
              return unreadCountAsync.when(
                data: (count) => Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        context.push('/notifications');
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            count > 9 ? '9+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                loading: () => IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => context.push('/notifications'),
                ),
                error: (_, __) => IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => context.push('/notifications'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CreatedBillsTab(),
          _InvitedBillsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to create bill page
          context.push('/create-bill');
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Bill'),
      ),
    );
  }
}

// Tab for bills created by current user
class _CreatedBillsTab extends ConsumerWidget {
  const _CreatedBillsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(myCreatedBillsProvider);

    return billsAsync.when(
      data: (bills) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myCreatedBillsProvider);
          },
          child: bills.isEmpty
              ? CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No bills created yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pull down to refresh',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    return _BillCard(
                      bill: bill,
                      isHost: true,
                    );
                  },
                ),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(myCreatedBillsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Tab for bills user is invited to
class _InvitedBillsTab extends ConsumerWidget {
  const _InvitedBillsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(myInvitedBillsProvider);

    return billsAsync.when(
      data: (bills) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myInvitedBillsProvider);
          },
          child: bills.isEmpty
              ? CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mail_outline,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No invitations yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pull down to refresh',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    return _BillCard(
                      bill: bill,
                      isHost: false,
                    );
                  },
                ),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(myInvitedBillsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Bill Card Widget
class _BillCard extends StatelessWidget {
  final Bill bill;
  final bool isHost;

  const _BillCard({
    required this.bill,
    required this.isHost,
  });

  Color _getStatusColor(BillStatus status) {
    switch (status) {
      case BillStatus.draft:
        return Colors.orange;
      case BillStatus.final_:
        return Colors.blue;
      case BillStatus.completed:
        return Colors.green;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to bill detail
          context.push('/bill/${bill.id}', extra: {'isHost': isHost});
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bill.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(bill.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bill.status.value,
                      style: TextStyle(
                        color: _getStatusColor(bill.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(bill.date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    isHost ? Icons.person : Icons.group,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isHost ? 'Host' : 'Guest',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (bill.taxPercent > 0 || bill.servicePercent > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (bill.taxPercent > 0)
                      Chip(
                        label: Text('Tax ${bill.taxPercent}%'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (bill.servicePercent > 0)
                      Chip(
                        label: Text('Service ${bill.servicePercent}%'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
