import 'package:aloo_sbji_mandi/core/service/post_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/phone_number_detector.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/ist_datetime.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onPostUpdated;

  const PostDetailScreen({super.key, required this.post, this.onPostUpdated});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _editCommentController = TextEditingController();
  final TextEditingController _editReplyController = TextEditingController();

  late Map<String, dynamic> _post;
  bool _isLiked = false;
  bool _isLoading = false;
  bool _isCommenting = false;
  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _currentUserId;
  String? _editingCommentId;
  String? _editingReplyId;
  String? _editingReplyCommentId;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
    _loadCurrentUser();
    _refreshPost();
  }

  Future<void> _loadCurrentUser() async {
    _currentUserId = await _postService.getCurrentUserId();
    await _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final likes = _post['likes'] as List? ?? [];
    final isLiked = await _postService.isPostLikedByUser(likes);
    if (mounted) {
      setState(() => _isLiked = isLiked);
    }
  }

  Future<void> _refreshPost() async {
    setState(() => _isLoading = true);
    try {
      final result = await _postService.getPost(_post['_id']);
      if (result['success'] && mounted) {
        final data = result['data'];
        // Backend returns { post: {...} } inside data
        final postData = data is Map && data.containsKey('post')
            ? data['post']
            : data;
        setState(() {
          _post = Map<String, dynamic>.from(postData);
          _isLoading = false;
        });
        await _checkIfLiked();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final previousState = _isLiked;
    setState(() => _isLiked = !_isLiked);

    final result = await _postService.toggleLike(_post['_id']);
    if (!result['success']) {
      setState(() => _isLiked = previousState);
      _showError(result['message'] ?? 'Failed to update like');
    } else {
      await _refreshPost();
      widget.onPostUpdated?.call();
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Check for phone number
    if (PhoneNumberDetector.containsPhoneNumber(text)) {
      _showPhoneNumberWarning();
      return;
    }

    setState(() => _isCommenting = true);
    final result = await _postService.addComment(_post['_id'], text);
    setState(() => _isCommenting = false);

    if (result['success']) {
      _commentController.clear();
      await _refreshPost();
      widget.onPostUpdated?.call();
    } else {
      _showError(result['message'] ?? 'Failed to add comment');
    }
  }

  Future<void> _addReply(String commentId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    // Check for phone number
    if (PhoneNumberDetector.containsPhoneNumber(text)) {
      _showPhoneNumberWarning();
      return;
    }

    setState(() => _isCommenting = true);
    final result = await _postService.replyToComment(
      _post['_id'],
      commentId,
      text,
    );
    setState(() => _isCommenting = false);

    if (result['success']) {
      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
      });
      await _refreshPost();
      widget.onPostUpdated?.call();
    } else {
      _showError(result['message'] ?? 'Failed to add reply');
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final result = await _postService.toggleCommentLike(
      _post['_id'],
      commentId,
    );
    if (result['success']) {
      await _refreshPost();
    } else {
      _showError(result['message'] ?? 'Failed to like comment');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_comment')),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _postService.deleteComment(_post['_id'], commentId);
      if (result['success']) {
        await _refreshPost();
        widget.onPostUpdated?.call();
      } else {
        _showError(result['message'] ?? 'Failed to delete comment');
      }
    }
  }

  void _startEditingComment(String commentId, String currentText) {
    setState(() {
      _editingCommentId = commentId;
      _editCommentController.text = currentText;
    });
  }

  void _cancelEditingComment() {
    setState(() {
      _editingCommentId = null;
      _editCommentController.clear();
    });
  }

  Future<void> _saveEditedComment(String commentId) async {
    final text = _editCommentController.text.trim();
    if (text.isEmpty) return;

    // Check for phone number
    if (PhoneNumberDetector.containsPhoneNumber(text)) {
      _showPhoneNumberWarning();
      return;
    }

    setState(() => _isCommenting = true);
    final result = await _postService.updateComment(
      _post['_id'],
      commentId,
      text,
    );
    setState(() => _isCommenting = false);

    if (result['success']) {
      _cancelEditingComment();
      await _refreshPost();
      widget.onPostUpdated?.call();
    } else {
      _showError(result['message'] ?? 'Failed to update comment');
    }
  }

  Future<void> _deleteReply(String commentId, String replyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reply'),
        content: const Text('Are you sure you want to delete this reply?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _postService.deleteReply(_post['_id'], commentId, replyId);
      if (result['success']) {
        await _refreshPost();
        widget.onPostUpdated?.call();
      } else {
        _showError(result['message'] ?? 'Failed to delete reply');
      }
    }
  }

  void _startEditingReply(String commentId, String replyId, String currentText) {
    setState(() {
      _editingReplyId = replyId;
      _editingReplyCommentId = commentId;
      _editReplyController.text = currentText;
    });
  }

  void _cancelEditingReply() {
    setState(() {
      _editingReplyId = null;
      _editingReplyCommentId = null;
      _editReplyController.clear();
    });
  }

  Future<void> _saveEditedReply(String commentId, String replyId) async {
    final text = _editReplyController.text.trim();
    if (text.isEmpty) return;

    // Check for phone number
    if (PhoneNumberDetector.containsPhoneNumber(text)) {
      _showPhoneNumberWarning();
      return;
    }

    setState(() => _isCommenting = true);
    final result = await _postService.updateReply(
      _post['_id'],
      commentId,
      replyId,
      text,
    );
    setState(() => _isCommenting = false);

    if (result['success']) {
      _cancelEditingReply();
      await _refreshPost();
      widget.onPostUpdated?.call();
    } else {
      _showError(result['message'] ?? 'Failed to update reply');
    }
  }

  Future<void> _sharePost() async {
    final author = _post['author'] ?? {};
    final authorName =
        '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim();
    final content = _post['content'] ?? '';

    final shareText =
        'Check out this post by $authorName:\n\n"$content"\n\n- Shared from Aloo Market App\n\nDownload Aloo Market App:\nhttps://play.google.com/store/apps/details?id=com.aloomarket.app';

    await Share.share(shareText);

    // No server share-count / refresh: opens native share only (count was misleading).
    // await _postService.trackShare(_post['_id']);
    // await _refreshPost();
    // widget.onPostUpdated?.call();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showPhoneNumberWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_disabled,
                  size: 35,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                PhoneNumberDetector.getWarningTitle()[isHindi ? 'hi' : 'en']!,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                PhoneNumberDetector.getWarningMessage()[isHindi ? 'hi' : 'en']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  PhoneNumberDetector.getReasonExplanation()[isHindi
                      ? 'hi'
                      : 'en']!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr('i_understand'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _editCommentController.dispose();
    _editReplyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('post')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPost,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostCard(),
                    const SizedBox(height: 16),
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostCard() {
    final author = _post['author'] ?? {};
    final firstName = author['firstName'] ?? '';
    final lastName = author['lastName'] ?? '';
    final role = author['role'] ?? 'farmer';
    final content = _post['content'] ?? '';
    final category = _post['category'] ?? 'general';
    final likes = (_post['likes'] as List?)?.length ?? 0;
    final comments = (_post['comments'] as List?)?.length ?? 0;
    final createdAt = _post['createdAt'];

    String timeAgo = _getTimeAgo(createdAt);
    final (roleIcon, roleColor, roleLabel) = _getRoleStyle(role);
    final categoryColor = _getCategoryColor(category);

    return Card(
      elevation: 4,
      shadowColor: AppColors.primaryGreen.withOpacity(0.3),
      surfaceTintColor: Colors.transparent,
      color: AppColors.cardBg(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor.withOpacity(0.2),
                  child: Icon(roleIcon, color: roleColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + role chip on the left (avoid Expanded on name — it pushed FARMER to the far right)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$firstName $lastName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
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
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
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
                      category.toUpperCase().replaceAll('-', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Content
            Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),

            const SizedBox(height: 16),
            const Divider(),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '$likes',
                  color: _isLiked ? Colors.red : Colors.grey[600]!,
                  onTap: _toggleLike,
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: '$comments',
                  color: Colors.grey[600]!,
                  onTap: () {
                    // Focus on comment input
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: tr('share'),
                  color: Colors.grey[600]!,
                  onTap: _sharePost,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    final comments = (_post['comments'] as List?) ?? [];

    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No comments yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                tr('be_first_to_comment'),
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trArgs('comments', {'count': comments.length.toString()}),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...comments.map((comment) => _buildCommentTile(comment)),
      ],
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final user = comment['user'] ?? {};
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final role = user['role'] ?? 'farmer';
    final text = comment['text'] ?? '';
    final commentId = comment['_id'] ?? '';
    final userId = user['_id'] ?? '';
    final likes = (comment['likes'] as List?) ?? [];
    final replies = (comment['replies'] as List?) ?? [];
    final createdAt = comment['createdAt'];

    final timeAgo = _getTimeAgo(createdAt);
    final (roleIcon, roleColor, _) = _getRoleStyle(role);
    final isMyComment = userId == _currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: AppColors.cardBg(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: roleColor.withOpacity(0.2),
                  child: Icon(roleIcon, color: roleColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                if (isMyComment)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                    iconSize: 20,
                    splashRadius: 18,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _startEditingComment(commentId, text);
                      } else if (value == 'delete') {
                        _deleteComment(commentId);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(tr('edit_btn')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                            const SizedBox(width: 8),
                            Text(tr('delete_btn')),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Edit mode or display mode
            if (_editingCommentId == commentId) ...[
              TextField(
                controller: _editCommentController,
                decoration: InputDecoration(
                  hintText: 'Edit your comment...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEditingComment,
                    child: Text(tr('cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _saveEditedComment(commentId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr('save_label')),
                  ),
                ],
              ),
            ] else ...[
              Text(text, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 8),

            // Comment actions
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleCommentLike(commentId),
                  child: Row(
                    children: [
                      FutureBuilder<bool>(
                        future: _postService.isCommentLikedByUser(likes),
                        builder: (context, snapshot) {
                          final isLiked = snapshot.data ?? false;
                          return Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isLiked ? Colors.red : Colors.grey[600],
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${likes.length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_replyingToCommentId == commentId) {
                        _replyingToCommentId = null;
                        _replyingToUserName = null;
                      } else {
                        _replyingToCommentId = commentId;
                        _replyingToUserName = '$firstName $lastName';
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        tr('reply'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (replies.isNotEmpty) ...[
                  const SizedBox(width: 20),
                  Text(
                    '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ],
            ),

            // Reply input
            if (_replyingToCommentId == commentId) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: 'Reply to $_replyingToUserName...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _addReply(commentId),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Replies list
            if (replies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(
                  children: replies
                      .map((reply) => _buildReplyTile(reply, commentId))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyTile(Map<String, dynamic> reply, String commentId) {
    final user = reply['user'] ?? {};
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final role = user['role'] ?? 'farmer';
    final text = reply['text'] ?? '';
    final replyId = reply['_id'] ?? '';
    final userId = user['_id'] ?? '';
    final createdAt = reply['createdAt'];

    final timeAgo = _getTimeAgo(createdAt);
    final (roleIcon, roleColor, _) = _getRoleStyle(role);
    final isMyReply = userId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: roleColor.withOpacity(0.2),
                child: Icon(roleIcon, color: roleColor, size: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (isMyReply)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                  iconSize: 18,
                  splashRadius: 16,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _startEditingReply(commentId, replyId, text);
                    } else if (value == 'delete') {
                      _deleteReply(commentId, replyId);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            tr('edit_btn'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red[400],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('delete_btn'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Edit mode or display mode
          if (_editingReplyId == replyId &&
              _editingReplyCommentId == commentId) ...[
            TextField(
              controller: _editReplyController,
              decoration: InputDecoration(
                hintText: 'Edit your reply...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primaryGreen),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancelEditingReply,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    tr('cancel'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _saveEditedReply(commentId, replyId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    tr('save_label'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: tr('write_comment'),
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isCommenting ? null : _addComment,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: _isCommenting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final postDate = DateTime.parse(createdAt).toIST();
      final now = nowIST();
      final difference = now.difference(postDate);
      if (difference.inDays > 7) {
        return '${postDate.day}/${postDate.month}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  (IconData, Color, String) _getRoleStyle(String role) {
    switch (role) {
      case 'farmer':
        return (Icons.agriculture, Colors.green, 'FARMER');
      case 'trader':
        return (Icons.store, Colors.orange, 'TRADER');
      case 'cold-storage':
        return (Icons.ac_unit, Colors.blue, 'STORAGE');
      default:
        return (Icons.person, Colors.grey, 'USER');
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'price-update':
        return Colors.blue;
      case 'tip':
        return Colors.green;
      case 'question':
        return Colors.orange;
      case 'news':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
