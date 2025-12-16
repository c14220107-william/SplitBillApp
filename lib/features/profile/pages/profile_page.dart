  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:image_picker/image_picker.dart';
  import 'dart:io';
  import 'package:splitbillapp/core/config/supabase_config.dart';
  import 'package:splitbillapp/features/auth/providers/auth_provider.dart';
  import 'package:splitbillapp/core/services/storage_service.dart';
  import 'package:splitbillapp/core/theme/theme_provider.dart';
  import 'privacy_policy_page.dart';


  class ProfilePage extends ConsumerStatefulWidget {
    const ProfilePage({super.key});

    @override
    ConsumerState<ProfilePage> createState() => _ProfilePageState();
  }

  class _ProfilePageState extends ConsumerState<ProfilePage> {
    bool _isLoading = false;
    String? _userName;
    String? _userEmail;
    String? _avatarUrl;

    @override
    void initState() {
      super.initState();
      _loadUserInfo();
    }

    Future<void> _loadUserInfo() async {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email;
        });

        // Load profile from database
        try {
          final response = await SupabaseConfig.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();

          setState(() {
            _userName = response['full_name'] as String?;
            _avatarUrl = response['avatar_url'] as String?;
          });
        } catch (e) {
          // Profile might not exist yet
          print('Error loading profile: $e');
        }
      }
    }

    Future<void> _uploadAvatar() async {
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 75,
        );

        if (image == null) return;
        if (!mounted) return;

        setState(() => _isLoading = true);
        final messenger = ScaffoldMessenger.of(context);

        final user = SupabaseConfig.client.auth.currentUser;
        if (user == null) return;

        // Upload to Supabase Storage
        final avatarUrl = await StorageService.uploadAvatar(
          File(image.path),
          user.id,
        );

        // Update profile in database
        await SupabaseConfig.client
            .from('profiles')
            .update({'avatar_url': avatarUrl})
            .eq('id', user.id);

        if (mounted) {
          setState(() {
            _avatarUrl = avatarUrl;
            _isLoading = false;
          });

          messenger.showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload avatar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Future<void> _logout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        setState(() => _isLoading = true);

        try {
          // Use auth provider to sign out
          await ref.read(authStateProvider.notifier).signOut();

          if (mounted) {
            // Navigate to login - router will handle redirect
            context.go('/login');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to logout: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }

    Future<void> _editProfile() async {
      final nameController = TextEditingController(text: _userName);

      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Profile'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, nameController.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (result != null && result.isNotEmpty && mounted) {
        setState(() => _isLoading = true);
        final messenger = ScaffoldMessenger.of(context);

        try {
          final user = SupabaseConfig.client.auth.currentUser;
          if (user != null) {
            await SupabaseConfig.client
                .from('profiles')
                .update({'full_name': result})
                .eq('id', user.id);

            if (mounted) {
              setState(() {
                _userName = result;
                _isLoading = false;
              });

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            messenger.showSnackBar(
              SnackBar(
                content: Text('Failed to update profile: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      nameController.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final user = SupabaseConfig.client.auth.currentUser;

      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blue,
                              backgroundImage: _avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null
                                  ? Text(
                                      (_userName?.isNotEmpty == true
                                              ? _userName![0]
                                              : _userEmail?[0] ?? 'U')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.blue,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: _uploadAvatar,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userName ?? 'No name set',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail ?? '',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _editProfile,
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Account Information
                  const Text(
                    'Account Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle: Text(_userEmail ?? ''),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.badge),
                          title: const Text('User ID'),
                          subtitle: Text(
                            user?.id ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Member Since'),
                          subtitle: Text(
                            user?.createdAt != null
                                ? _formatDate(DateTime.parse(user!.createdAt))
                                : 'Unknown',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Settings Section
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Notifications'),
                          trailing: Switch(
                            value: true,
                            onChanged: (value) {
                              // TODO: Implement notification settings
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.dark_mode),
                          title: const Text('Dark Mode'),
                          trailing: Consumer(
                            builder: (context, ref, child) {
                              final themeMode = ref.watch(themeModeProvider);
                              final isDark = themeMode == ThemeMode.dark;

                              return Switch(
                                value: isDark,
                                onChanged: (value) {
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .toggleTheme(value);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // About Section
                  const Text(
                    'About',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info),
                          title: const Text('App Version'),
                          trailing: const Text('1.0.0'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to privacy policy
                             context.push('/privacy-policy');
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.description),
                          title: const Text('Terms of Service'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to terms
                            context.push('/terms-of-service');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout Button
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      );
    }

    String _formatDate(DateTime date) {
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
