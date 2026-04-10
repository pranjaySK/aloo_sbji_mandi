import 'package:aloo_sbji_mandi/core/models/chat_models.dart';
import 'package:aloo_sbji_mandi/core/service/chat_service.dart';
import 'package:aloo_sbji_mandi/core/service/choupal_notification_state.dart';
import 'package:aloo_sbji_mandi/core/service/post_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/role_shell_scroll_padding.dart';
import 'package:aloo_sbji_mandi/core/utils/auth_error_helper.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_detail_screen.dart';
import 'package:aloo_sbji_mandi/screens/chat/create_post_screen.dart';
import 'package:aloo_sbji_mandi/screens/chat/post_detail_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/ist_datetime.dart';

class ChaupalChatScreen extends StatefulWidget {
  const ChaupalChatScreen({super.key});

  @override
  State<ChaupalChatScreen> createState() => _ChaupalChatScreenState();
}

class _ChaupalChatScreenState extends State<ChaupalChatScreen> {
  bool isPostSelected = true;
  final ChatService _chatService = ChatService();
  final PostService _postService = PostService();
  List<Conversation> _conversations = [];
  List<dynamic> _posts = [];
  bool _isLoadingChats = false;
  bool _isLoadingPosts = false;
  bool _isChatAuthError = false;
  String? _chatError;
  String? _postError;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPosts = true;
      _postError = null;
    });

    try {
      final result = await _postService.getAllPosts();
      if (!mounted) return;
      setState(() {
        _isLoadingPosts = false;
        if (result['success']) {
          _posts = result['data']['posts'] ?? [];
        } else {
          _postError = result['message'];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postError = 'Failed to load posts: $e';
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingChats = true;
      _chatError = null;
      _isChatAuthError = false;
    });

    try {
      final conversations = await _chatService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoadingChats = false;
      });
    } catch (e) {
      if (!mounted) return;
      final isAuth =
          e.toString().contains('SESSION_EXPIRED') ||
          AuthErrorHelper.isAuthError(e.toString());
      setState(() {
        _isChatAuthError = isAuth;
        _chatError = isAuth
            ? AuthErrorHelper.getAuthErrorMessage(
                isHindi: AppLocalizations.isHindi,
              )
            : 'Failed to load chats: $e';
        _isLoadingChats = false;
      });
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'farmer':
        return tr('role_farmer');
      case 'trader':
        return tr('role_trader');
      case 'cold-storage':
        return tr('role_storage');
      default:
        return tr('role_user');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(
        title: isPostSelected ? tr('chaupal_title') : tr('messages_title'),
        showBackButton: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          /// Toggle
          ValueListenableBuilder<bool>(
            valueListenable: ChoupalNotificationState.hasChatTabNotification,
            builder: (context, hasChatNotification, _) => PostChatToggle(
              isPostSelected: isPostSelected,
              showChatBadge: hasChatNotification,
              onToggle: (value) {
                setState(() {
                  isPostSelected = value;
                });
                if (!value) {
                  _loadConversations();
                  // User visited chats — clear all notification dots
                  ChoupalNotificationState.markChatsVisited();
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          /// Content
          Expanded(
            child: isPostSelected ? _buildPostsList() : _buildChatsList(),
          ),
        ],
      ),
      floatingActionButton: isPostSelected
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryGreen,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostScreen(),
                  ),
                );
                if (result == true) {
                  _loadPosts();
                }
              },
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildPostsList() {
    if (_isLoadingPosts) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_postError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_postError!, style: TextStyle(color: Colors.red[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              tr('no_posts_yet'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('be_first_to_share'),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: RoleShellScrollPadding.chaupalList,
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return RealPostTile(post: _posts[index], onPostUpdated: _loadPosts);
        },
      ),
    );
  }

  Widget _buildChatsList() {
    if (_isChatAuthError) {
      return AuthErrorHelper.buildSessionExpiredView(
        context: context,
        isHindi: AppLocalizations.isHindi,
      );
    }

    if (_isLoadingChats) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_chatError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _chatError!,
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              tr('no_conversations_yet'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('start_chat_desc'),
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            // Start New Chat button hidden for now
            // const SizedBox(height: 24),
            // ElevatedButton.icon(
            //   onPressed: () async {
            //     final result = await Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const NewChatScreen(),
            //       ),
            //     );
            //     if (result == true) {
            //       _loadConversations();
            //     }
            //   },
            //   icon: const Icon(Icons.add, color: Colors.white),
            //   label: Text(
            //     tr('start_new_chat'),
            //     style: const TextStyle(color: Colors.white),
            //   ),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: AppColors.primaryGreen,
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 24,
            //       vertical: 12,
            //     ),
            //   ),
            // ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: RoleShellScrollPadding.chaupalList,
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          debugPrint("chatData: ${conversation.lastMessage}");
          return _buildConversationTile(conversation);
        },
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final otherUser = conversation.otherUser;

    IconData roleIcon;
    Color roleColor;
    switch (otherUser.role) {
      case 'farmer':
        roleIcon = Icons.agriculture;
        roleColor = Colors.green;
        break;
      case 'trader':
        roleIcon = Icons.store;
        roleColor = Colors.orange;
        break;
      case 'cold-storage':
        roleIcon = Icons.ac_unit;
        roleColor = Colors.blue;
        break;
      default:
        roleIcon = Icons.person;
        roleColor = Colors.grey;
    }

    String timeAgo = '';
    if (conversation.lastMessageAt != null) {
      final now = nowIST();
      final lastMsg = conversation.lastMessageAt!.toIST();
      final difference = now.difference(lastMsg);
      if (difference.inDays > 7) {
        timeAgo = '${lastMsg.day}/${lastMsg.month}';
      } else if (difference.inDays > 0) {
        timeAgo = '${difference.inDays} ${tr('d_ago')}';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours} ${tr('h_ago')}';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes} ${tr('m_ago')}';
      } else {
        timeAgo = tr('just_now');
      }
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversation.id,
              otherUser: otherUser,
            ),
          ),
        );
        if (mounted) _loadConversations();
      },
      child: Card(
        elevation: 4,
        shadowColor: AppColors.primaryGreen.withOpacity(0.3),
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: roleColor.withOpacity(0.2),
                    child: Icon(roleIcon, color: roleColor, size: 24),
                  ),
                  // Online indicator
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: otherUser.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${otherUser.firstName} ${otherUser.lastName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getRoleLabel(otherUser.role),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage ?? tr('no_messages_yet'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (conversation.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostChatToggle extends StatelessWidget {
  final bool isPostSelected;
  final ValueChanged<bool> onToggle;
  final bool showChatBadge;

  const PostChatToggle({
    super.key,
    required this.isPostSelected,
    required this.onToggle,
    this.showChatBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _toggleButton(
            text: tr('posts'),
            selected: isPostSelected,
            onTap: () => onToggle(true),
          ),
          _toggleButton(
            text: tr('chats'),
            selected: !isPostSelected,
            onTap: () => onToggle(false),
            showBadge: showChatBadge && isPostSelected,
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black,
                ),
              ),
              if (showBadge)
                Positioned(
                  right: -10,
                  top: -4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostTile extends StatelessWidget {
  final int index;

  const PostTile({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: AppColors.primaryGreen, // GREEN SHADOW
      surfaceTintColor: Colors.transparent, // Material 3 fix
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Post Item #$index",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// Real Post Tile with actual data - Interactive version
class RealPostTile extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onPostUpdated;

  const RealPostTile({super.key, required this.post, this.onPostUpdated});

  @override
  State<RealPostTile> createState() => _RealPostTileState();
}

class _RealPostTileState extends State<RealPostTile> {
  final PostService _postService = PostService();
  late Map<String, dynamic> _post;
  bool _isLiked = false;
  bool _isLiking = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _checkIfLiked();
    _loadCurrentUserId();
  }

  @override
  void didUpdateWidget(RealPostTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _post = widget.post;
      _checkIfLiked();
    }
  }

  Future<void> _checkIfLiked() async {
    final likes = _post['likes'] as List? ?? [];
    final isLiked = await _postService.isPostLikedByUser(likes);
    if (mounted) {
      setState(() => _isLiked = isLiked);
    }
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await _postService.getCurrentUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    setState(() {
      _isLiking = true;
      _isLiked = !_isLiked;
      // Optimistic update of likes count
      final likes = List.from(_post['likes'] ?? []);
      if (_isLiked) {
        likes.add({'_id': 'temp'});
      } else if (likes.isNotEmpty) {
        likes.removeLast();
      }
      _post = {..._post, 'likes': likes};
    });

    final result = await _postService.toggleLike(_post['_id']);

    if (!result['success'] && mounted) {
      // Revert on failure
      setState(() {
        _isLiked = !_isLiked;
        final likes = List.from(_post['likes'] ?? []);
        if (!_isLiked && likes.isNotEmpty) {
          likes.removeLast();
        } else {
          likes.add({'_id': 'temp'});
        }
        _post = {..._post, 'likes': likes};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to like'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLiking = false);
    }
    widget.onPostUpdated?.call();
  }

  Future<void> _sharePost() async {
    final author = _post['author'] ?? {};
    final authorName =
        '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim();
    final content = _post['content'] ?? '';

    final shareText =
        'Check out this post by $authorName:\n\n"$content"\n\n- Shared from Aloo Market App\n\nDownload Aloo Market App:\nhttps://play.google.com/store/apps/details?id=com.aloomarket.app';

    await Share.share(shareText);

    // Same as post detail: native share only — no share count / track / refresh.
    // await _postService.trackShare(_post['_id']);
    // if (mounted) {
    //   setState(() {
    //     _post = {..._post, 'shares': (_post['shares'] ?? 0) + 1};
    //   });
    // }
    // widget.onPostUpdated?.call();
  }

  void _openPostDetail() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(post: _post, onPostUpdated: widget.onPostUpdated),
      ),
    );
    // Refresh the post state when coming back
    widget.onPostUpdated?.call();
  }

  String? _postAuthorId() {
    final author = _post['author'];
    if (author is Map<String, dynamic>) {
      return author['_id']?.toString();
    }
    return author?.toString();
  }

  bool get _canManagePost {
    final authorId = _postAuthorId();
    if (_currentUserId == null || authorId == null) return false;
    return _currentUserId == authorId;
  }

  Future<void> _showEditPostDialog() async {
    final contentController = TextEditingController(
      text: (_post['content'] ?? '').toString(),
    );
    String selectedCategory = (_post['category'] ?? 'general').toString();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(tr('edit_action')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: tr('post_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'tip', child: Text('Tips')),
                  DropdownMenuItem(value: 'question', child: Text('Question')),
                  DropdownMenuItem(value: 'news', child: Text('News')),
                  DropdownMenuItem(
                    value: 'price-update',
                    child: Text('Price Update'),
                  ),
                ],
                onChanged: isSubmitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setDialogState(() => selectedCategory = value);
                        }
                      },
                decoration: InputDecoration(
                  labelText: tr('choose_category'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(tr('cancel_btn')),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final content = contentController.text.trim();
                      if (content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('please_write_something')),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final result = await _postService.updatePost(
                        _post['_id'].toString(),
                        content: content,
                        category: selectedCategory,
                      );
                      if (!mounted) return;

                      if (result['success'] == true) {
                        final updatedPost = result['data']?['post'];
                        if (updatedPost is Map<String, dynamic>) {
                          setState(() => _post = updatedPost);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.isHindi
                                  ? 'पोस्ट अपडेट हो गई'
                                  : 'Post updated',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        widget.onPostUpdated?.call();
                      } else {
                        setDialogState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Update failed'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('save')),
            ),
          ],
        ),
      ),
    );
    contentController.dispose();
  }

  Future<void> _confirmDeletePost() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_action')),
        content: Text(
          AppLocalizations.isHindi
              ? 'क्या आप यह पोस्ट हटाना चाहते हैं?'
              : 'Are you sure you want to delete this post?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('delete_action')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final result = await _postService.deletePost(_post['_id'].toString());
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.isHindi ? 'पोस्ट हटा दी गई' : 'Post deleted',
          ),
          backgroundColor: Colors.green,
        ),
      );
      widget.onPostUpdated?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Delete failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'price-update':
        return tr('price_update').toUpperCase();
      case 'tip':
        return tr('tips').toUpperCase();
      case 'question':
        return tr('question').toUpperCase();
      case 'news':
        return tr('news').toUpperCase();
      default:
        return tr('general').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = _post['author'] ?? {};
    final firstName = author['firstName'] ?? '';
    final lastName = author['lastName'] ?? '';
    final role = author['role'] ?? 'farmer';
    final content = _post['content'] ?? '';
    final category = _post['category'] ?? 'general';
    final likes = (_post['likes'] as List?)?.length ?? 0;
    final comments = (_post['comments'] as List?)?.length ?? 0;
    final createdAt = _post['createdAt'];

    // Calculate time ago
    String timeAgo = '';
    if (createdAt != null) {
      final postDate = DateTime.parse(createdAt).toIST();
      final now = nowIST();
      final difference = now.difference(postDate);
      if (difference.inDays > 7) {
        timeAgo = '${postDate.day}/${postDate.month}';
      } else if (difference.inDays > 0) {
        timeAgo = '${difference.inDays} ${tr('d_ago')}';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours} ${tr('h_ago')}';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes} ${tr('m_ago')}';
      } else {
        timeAgo = tr('just_now');
      }
    }

    // Role styling
    IconData roleIcon;
    Color roleColor;
    String roleLabel;
    switch (role) {
      case 'farmer':
        roleIcon = Icons.agriculture;
        roleColor = Colors.green;
        roleLabel = tr('role_farmer');
        break;
      case 'trader':
        roleIcon = Icons.store;
        roleColor = Colors.orange;
        roleLabel = tr('role_trader');
        break;
      case 'cold-storage':
        roleIcon = Icons.ac_unit;
        roleColor = Colors.blue;
        roleLabel = tr('role_storage');
        break;
      default:
        roleIcon = Icons.person;
        roleColor = Colors.grey;
        roleLabel = tr('role_user');
    }

    // Category styling
    Color categoryColor;
    switch (category) {
      case 'price-update':
        categoryColor = Colors.blue;
        break;
      case 'tip':
        categoryColor = Colors.green;
        break;
      case 'question':
        categoryColor = Colors.orange;
        break;
      case 'news':
        categoryColor = Colors.purple;
        break;
      default:
        categoryColor = Colors.grey;
    }

    return GestureDetector(
      onTap: _openPostDetail,
      child: Card(
        elevation: 4,
        shadowColor: AppColors.primaryGreen.withOpacity(0.3),
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with author info
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: roleColor.withOpacity(0.2),
                    child: Icon(roleIcon, color: roleColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$firstName $lastName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (category != 'general' || _canManagePost)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (category != 'general')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getCategoryLabel(category),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        if (category != 'general' && _canManagePost)
                          const SizedBox(width: 4),
                        if (_canManagePost)
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            splashRadius: 18,
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[700],
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditPostDialog();
                              } else if (value == 'delete') {
                                _confirmDeletePost();
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(tr('edit_action')),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr('delete_action'),
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Post content
              Text(
                content,
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Footer with interactive likes, comments, and shares
              Row(
                children: [
                  // Like button
                  GestureDetector(
                    onTap: _toggleLike,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isLiked
                            ? Colors.red.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey(_isLiked),
                              size: 20,
                              color: _isLiked ? Colors.red : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likes',
                            style: TextStyle(
                              color: _isLiked ? Colors.red : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: _isLiked
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Comment button (navigates to detail)
                  GestureDetector(
                    onTap: _openPostDetail,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$comments',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Share button
                  GestureDetector(
                    onTap: _sharePost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tr('share'),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
