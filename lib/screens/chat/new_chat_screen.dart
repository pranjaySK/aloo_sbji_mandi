import 'package:flutter/material.dart';

import '../../core/models/chat_models.dart';
import '../../core/service/chat_service.dart';
import '../../core/utils/app_localizations.dart';
import '../../core/utils/custom_rounded_app_bar.dart';
import '../../theme/app_colors.dart';
import 'chat_detail_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  List<ChatUser> _users = [];
  List<ChatUser> _filteredUsers = [];
  bool _isLoading = true;
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {'value': null, 'label': 'All', 'icon': Icons.people, 'color': Colors.grey},
    {
      'value': 'farmer',
      'label': tr('farmers'),
      'icon': Icons.agriculture,
      'color': Colors.green,
    },
    {
      'value': 'trader',
      'label': tr('traders'),
      'icon': Icons.store,
      'color': Colors.orange,
    },
    {
      'value': 'cold-storage',
      'label': tr('cold_storage'),
      'icon': Icons.ac_unit,
      'color': Colors.blue,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roles.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _selectedRole = _roles[_tabController.index]['value'];
      _filterUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await _chatService.getChatableUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('failed_to_load_users'))));
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch =
            query.isEmpty ||
            user.fullName.toLowerCase().contains(query) ||
            (user.phone?.contains(query) ?? false);
        final matchesRole = _selectedRole == null || user.role == _selectedRole;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _startChat(ChatUser user) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );

      final conversationId = await _chatService.getOrCreateConversation(
        user.id,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversationId,
              otherUser: user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('failed_to_start_chat'))));
      }
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'farmer':
        return Icons.agriculture;
      case 'trader':
        return Icons.store;
      case 'cold-storage':
        return Icons.ac_unit;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'farmer':
        return Colors.green;
      case 'trader':
        return Colors.orange;
      case 'cold-storage':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('new_chat')),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filterUsers(),
              decoration: InputDecoration(
                hintText: tr('search_by_name_phone'),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryGreen,
                ),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Role Filter Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryGreen,
              tabs: _roles
                  .map(
                    (role) => Tab(
                      child: Row(
                        children: [
                          Icon(role['icon'], size: 18),
                          const SizedBox(width: 6),
                          Text(role['label']),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('no_users_found'),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _buildUserTile(user);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(ChatUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
          child: Icon(
            _getRoleIcon(user.role),
            color: _getRoleColor(user.role),
            size: 24,
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user.roleDisplay,
                style: TextStyle(fontSize: 11, color: _getRoleColor(user.role)),
              ),
            ),
            if (user.phone != null) ...[
              const SizedBox(height: 4),
              Text(
                user.phone!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.chat, color: AppColors.primaryGreen),
          onPressed: () => _startChat(user),
        ),
        onTap: () => _startChat(user),
      ),
    );
  }
}
