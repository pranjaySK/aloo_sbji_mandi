import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/chat_models.dart';
import '../../core/models/deal_model.dart';
import '../../core/service/chat_service.dart';
import '../../core/service/deal_service.dart';
import '../../core/service/payment_service.dart';
import '../../core/service/receipt_service.dart';
import '../../core/utils/app_localizations.dart';
import '../../core/utils/custom_rounded_app_bar.dart';
import '../../core/utils/ist_datetime.dart';
import '../../core/utils/phone_number_detector.dart';
import '../../theme/app_colors.dart';
import '../receipt/receipt_view_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final ChatUser otherUser;
  final String? contextType; // To check if this is a cold-storage conversation
  final double? initialQuantity; // Auto-fill quantity for deal
  final double? initialPrice; // Auto-fill price for deal
  final String? listingRefId; // Listing reference ID (e.g. ALM-XXXXX)

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.otherUser,
    this.contextType,
    this.initialQuantity,
    this.initialPrice,
    this.listingRefId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final DealService _dealService = DealService();
  final PaymentService _paymentService = PaymentService();
  final ReceiptService _receiptService = ReceiptService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  List<Deal> _deals = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserRole;
  String? _currentUserName;
  bool _isOtherUserOnline = false;
  bool _isOtherUserTyping = false;
  Timer? _typingTimer;
  Timer? _refreshTimer; // Periodic refresh fallback for missed socket events

  // Deal action loading states
  bool _isProposingDeal = false;
  bool _isConfirmingDeal = false;
  bool _isCancellingDeal = false;
  final bool _isRequestingPayment = false;
  bool _isConfirmingPayment = false;

  // Track message IDs whose action buttons have already been tapped (prevents double-tap)
  final Set<String> _processedMessageIds = {};

  // Pending closing call details for payment flow
  DealDetails? _pendingClosingCallDetails;

  @override
  void initState() {
    super.initState();
    _startChat();
  }

  @override
  void dispose() {
    // Leave conversation room and remove listeners
    _chatService.leaveConversation(widget.conversationId);
    _chatService.removeMessageListener(_onMessageReceived);
    _chatService.removeOnlineStatusListener(_onOnlineStatusChanged);
    _chatService.removeTypingListener(_onTypingStatusChanged);
    _chatService.removeReadListener(_onMessagesRead);

    _typingTimer?.cancel();
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load current user first, then initialize chat
  Future<void> _startChat() async {
    await _loadCurrentUser();
    if (!mounted) return;
    await _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Connect to socket if not connected
    await _chatService.connectSocket();
    if (!mounted) return;

    // Join conversation room (will auto-join on connect if socket isn't ready yet)
    _chatService.joinConversation(widget.conversationId);

    // Setup listeners
    _chatService.addMessageListener(_onMessageReceived);
    _chatService.addOnlineStatusListener(_onOnlineStatusChanged);
    _chatService.addTypingListener(_onTypingStatusChanged);
    _chatService.addReadListener(_onMessagesRead);

    // Set initial online status
    setState(() {
      _isOtherUserOnline = widget.otherUser.isOnline;
    });

    // Load messages
    await _loadMessages();

    // Start periodic refresh as fallback for missed socket events
    _startPeriodicRefresh();
  }

  /// Periodically check for new messages in case socket events are missed
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForNewMessages();
    });
  }

  /// Check if there are new messages from the server
  Future<void> _checkForNewMessages() async {
    if (!mounted || _isLoading) return;
    try {
      final messages = await _chatService.getMessages(widget.conversationId);
      if (!mounted) return;
      // Only update if new messages arrived
      if (messages.length > _messages.length) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
        // Mark as read
        _chatService.markAsRead(widget.conversationId);
      }
    } catch (_) {
      // Silently ignore refresh errors
    }
  }

  void _onMessageReceived(Map<String, dynamic> data) {
    if (!mounted) return;

    // Check if message belongs to this conversation
    if (data['conversationId'] == widget.conversationId) {
      final message = Message.fromSocketData(data);

      // Avoid duplicates
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();

        // Mark as read immediately
        _chatService.markAsRead(widget.conversationId);
      }
    }
  }

  void _onOnlineStatusChanged(String oderId, bool isOnline) {
    if (!mounted) return;
    if (oderId == widget.otherUser.id) {
      setState(() {
        _isOtherUserOnline = isOnline;
      });
    }
  }

  void _onTypingStatusChanged(String oderId, String userName, bool isTyping) {
    if (!mounted) return;
    if (oderId == widget.otherUser.id) {
      setState(() {
        _isOtherUserTyping = isTyping;
      });
    }
  }

  void _onMessagesRead(String conversationId, String readBy) {
    if (!mounted) return;
    if (conversationId == widget.conversationId &&
        readBy == widget.otherUser.id) {
      // Update all messages to show read status
      setState(() {
        _messages = _messages
            .map((m) => m.copyWith(status: 'read', isRead: true))
            .toList();
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final userJson = prefs.getString('user');
    if (userJson != null) {
      final userData = json.decode(userJson);
      setState(() {
        _currentUserId = userData['_id'];
        _currentUserRole = userData['role'];
        final firstName = userData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? '';
        _currentUserName = '$firstName $lastName'.trim();
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getMessages(widget.conversationId);

      // Also load deals for this conversation if it's a deal-eligible chat
      if (_isDealEligibleChat) {
        await _loadDeals();
      }

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _computeProcessedMessageIds();
      _scrollToBottom();

      // Mark as read
      await _chatService.markAsRead(widget.conversationId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('failed_to_load_messages'))));
      }
    }
  }

  /// Scan messages and pre-populate _processedMessageIds for cards that already have responses.
  /// This ensures buttons stay hidden after revisiting the chat.
  void _computeProcessedMessageIds() {
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];

      if (msg.messageType == 'closing_call') {
        // Check if there's a response (accepted or cancelled) before the next closing_call
        for (int j = i + 1; j < _messages.length; j++) {
          if (_messages[j].messageType == 'closing_call') break;
          if (_messages[j].messageType == 'closing_call_accepted' ||
              _messages[j].content.contains('Closing Call was cancelled')) {
            setState(() => _processedMessageIds.add(msg.id));
            break;
          }
        }
      }

      if (msg.messageType == 'closing_call_accepted') {
        for (int j = i + 1; j < _messages.length; j++) {
          if (_messages[j].messageType == 'closing_call_accepted') break;
          if (_messages[j].messageType == 'payment_shared') {
            setState(() => _processedMessageIds.add(msg.id));
            break;
          }
        }
      }

      if (msg.messageType == 'payment_shared') {
        for (int j = i + 1; j < _messages.length; j++) {
          if (_messages[j].messageType == 'payment_shared') break;
          if (_messages[j].messageType == 'payment_sent') {
            setState(() => _processedMessageIds.add(msg.id));
            break;
          }
        }
      }

      if (msg.messageType == 'payment_sent') {
        for (int j = i + 1; j < _messages.length; j++) {
          if (_messages[j].messageType == 'payment_sent') break;
          if (_messages[j].messageType == 'deal_closed' ||
              _messages[j].content.contains('Payment not received')) {
            setState(() => _processedMessageIds.add(msg.id));
            break;
          }
        }
      }
    }
  }

  Future<void> _loadDeals() async {
    try {
      final deals = await _dealService.getDealsForConversation(
        widget.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _deals = deals;
      });
    } catch (_) {
      // Ignore deal loading errors
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTyping() {
    // Send typing indicator
    _chatService.sendTypingStatus(widget.conversationId, true);

    // Cancel existing timer
    _typingTimer?.cancel();

    // Set timer to stop typing indicator
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.sendTypingStatus(widget.conversationId, false);
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    // Check for phone number
    if (PhoneNumberDetector.containsPhoneNumber(content)) {
      _showPhoneNumberWarning();
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    // Stop typing indicator
    _chatService.sendTypingStatus(widget.conversationId, false);

    try {
      // Send via REST API (also emits via socket on backend)
      final message = await _chatService.sendMessage(
        widget.conversationId,
        content,
      );
      setState(() {
        // Avoid duplicate if polling already added this message
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('failed_to_send_message'))));
      }
    }
  }

  void _showPhoneNumberWarning() {
    final isHindi = AppLocalizations.isHindi;
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  String _formatTime(DateTime dateTime) {
    final ist = dateTime.toIST();
    final hour = ist.hour.toString().padLeft(2, '0');
    final minute = ist.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dateTime) {
    final ist = dateTime.toIST();
    final now = nowIST();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(ist.year, ist.month, ist.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${ist.day}/${ist.month}/${ist.year}';
    }
  }

  // Check if this is a cold storage chat (farmer <-> cold storage owner)
  bool get _isColdStorageChat {
    return widget.contextType == 'cold-storage' ||
        widget.contextType == 'booking' ||
        widget.otherUser.role == 'cold-storage' ||
        _currentUserRole == 'cold-storage';
  }

  // Check if this is a deal-eligible chat (exclude aloo-mitra chats)
  bool get _isDealEligibleChat {
    // Disable deals when chatting with aloo-mitra (service providers)
    if (widget.otherUser.role == 'aloo-mitra') {
      return false;
    }
    // Enable deals for all other chats
    return true;
  }

  // Check if this is a farmer-vendor chat
  bool get _isVendorChat {
    return widget.contextType == 'listing' ||
        widget.otherUser.role == 'vendor' ||
        _currentUserRole == 'vendor' ||
        ((_currentUserRole == 'farmer' && widget.otherUser.role == 'vendor') ||
            (_currentUserRole == 'vendor' &&
                widget.otherUser.role == 'farmer'));
  }

  // Get active deal for this conversation
  Deal? get _activeDeal {
    try {
      return _deals.firstWhere((d) => d.isPending);
    } catch (_) {
      return null;
    }
  }

  // Get closed deal for this conversation
  Deal? get _closedDeal {
    try {
      return _deals.firstWhere((d) => d.isClosed);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F8C9),
      appBar: CustomRoundedAppBar(
        title: widget.otherUser.fullName,
        actions: [
          // Only show "Deal Pakki Kare" button if NOT aloo-mitra user and in deal-eligible chat
          if (_currentUserRole != 'aloo-mitra' && _isDealEligibleChat)
            GestureDetector(
              onTap: _showClosingCallDialog,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('👉 ', style: const TextStyle(fontSize: 14)),
                    Text(
                      tr('close_the_deal'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.handshake,
                      color: Colors.green.shade700,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // User info header
          _buildUserInfoHeader(),

          // Deal section (for cold storage and vendor chats)
          if (_isDealEligibleChat) _buildDealSection(),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessagesList(),
          ),

          // Input Field
          _buildInputField(),
        ],
      ),
    );
  }

  // Build the deal section
  Widget _buildDealSection() {
    final activeDeal = _activeDeal;
    final closedDeal = _closedDeal;

    // PRIORITY: Active deal always takes precedence over closed deals
    // Check active deal FIRST, then closed deal
    if (activeDeal != null) {
      // Determine if current user is the farmer or owner IN THIS DEAL (not by role)
      final isUserFarmerInDeal = activeDeal.farmer.id == _currentUserId;
      final hasConfirmed = isUserFarmerInDeal
          ? activeDeal.farmerConfirmed
          : activeDeal.ownerConfirmed;
      final otherHasConfirmed = isUserFarmerInDeal
          ? activeDeal.ownerConfirmed
          : activeDeal.farmerConfirmed;
      final otherPartyName = isUserFarmerInDeal
          ? activeDeal.coldStorageOwner.firstName
          : activeDeal.farmer.firstName;

      // Show pending request banner if other party confirmed but current user hasn't
      if (otherHasConfirmed && !hasConfirmed) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.orange.shade100, Colors.amber.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.orange.shade400, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Pending request banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.pending_actions,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('request_pending'),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              trArgs('party_confirmed_deal', {
                                'name': otherPartyName,
                              }),
                              style: GoogleFonts.inter(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      trArgs('deal_summary_short', {
                        'quantity': activeDeal.quantity.toString(),
                        'price': activeDeal.pricePerTon.toString(),
                      }),
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      trArgs('deal_total_amount', {
                        'amount': activeDeal.totalAmount.toString(),
                      }),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('click_below_to_confirm'),
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConfirmingDeal
                            ? null
                            : () => _confirmDeal(activeDeal.id),
                        icon: _isConfirmingDeal
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.handshake, size: 20),
                        label: Text(
                          _isConfirmingDeal
                              ? tr('confirming')
                              : tr('confirm_deal_done'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isConfirmingDeal
                              ? Colors.grey
                              : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: (_isConfirmingDeal || _isCancellingDeal)
                            ? null
                            : () => _cancelDeal(activeDeal.id),
                        icon: _isCancellingDeal
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.close, size: 16),
                        label: Text(
                          _isCancellingDeal
                              ? tr('cancelling')
                              : tr('cancel_deal'),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Current user has confirmed, waiting for other party
      if (hasConfirmed && !otherHasConfirmed) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('waiting_for_confirmation'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trArgs('you_confirmed_waiting', {
                            'name': otherPartyName,
                          }),
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trArgs('deal_summary_short', {
                        'quantity': activeDeal.quantity.toString(),
                        'price': activeDeal.pricePerTon.toString(),
                      }),
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      trArgs('deal_preview_total', {
                        'total': activeDeal.totalAmount.toString(),
                      }),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trArgs('payment_option_after_confirm', {
                        'name': otherPartyName,
                      }),
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancellingDeal
                      ? null
                      : () => _cancelDeal(activeDeal.id),
                  icon: _isCancellingDeal
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close, size: 16),
                  label: Text(
                    _isCancellingDeal ? tr('cancelling') : tr('cancel_deal'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Neither has confirmed yet - show Deal Done button
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  tr('deal_proposed'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              trArgs('deal_summary_with_duration', {
                'quantity': activeDeal.quantity.toString(),
                'price': activeDeal.pricePerTon.toString(),
                'duration': activeDeal.duration.toString(),
              }),
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              trArgs('deal_total_amount', {
                'amount': activeDeal.totalAmount.toString(),
              }),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmDeal(activeDeal.id),
                icon: const Icon(Icons.check_circle, size: 20),
                label: Text(
                  tr('deal_done'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelDeal(activeDeal.id),
                icon: const Icon(Icons.close, size: 18),
                label: Text(tr('cancel_btn')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No active deal — check for closed deal
    if (closedDeal != null) {
      // Determine if current user is the farmer in THIS DEAL (not by role)
      final isUserFarmerInDeal = closedDeal.farmer.id == _currentUserId;
      final paymentStatus = closedDeal.paymentStatus;
      final isPaid = paymentStatus == 'paid';
      final payerConfirmed = closedDeal.payerConfirmed;
      final receiverConfirmed = closedDeal.receiverConfirmed;

      // If payment is completed, don't show the closed deal - show Propose Deal button instead
      // This allows users to start a fresh new deal
      // NOTE: Propose Deal button commented out — deals are now made via chat only
      if (isPaid) {
        return const SizedBox.shrink();
        // return Container(
        //   margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        //   child: ElevatedButton.icon(
        //     onPressed: _isProposingDeal ? null : _showProposeDealDialog,
        //     icon: _isProposingDeal
        //         ? const SizedBox(
        //             width: 20,
        //             height: 20,
        //             child: CircularProgressIndicator(
        //               strokeWidth: 2,
        //               color: Colors.white,
        //             ),
        //           )
        //         : const Icon(Icons.handshake, size: 20, color: Colors.white),
        //     label: Text(
        //       _isProposingDeal ? tr('sending_proposal') : tr('propose_deal'),
        //       style: const TextStyle(
        //         fontSize: 15,
        //         fontWeight: FontWeight.w600,
        //         color: Colors.white,
        //       ),
        //     ),
        //     style: ElevatedButton.styleFrom(
        //       backgroundColor: AppColors.primaryGreen,
        //       elevation: 3,
        //       shadowColor: AppColors.primaryGreen.withOpacity(0.4),
        //       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(12),
        //       ),
        //     ),
        //   ),
        // );
      }

      // In a typical deal: coldStorageOwner (buyer) is payer, farmer is receiver
      // But we allow either party to confirm either way
      final hasUserConfirmedPayment = payerConfirmed || receiverConfirmed;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid ? Icons.check : Icons.handshake,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Show "Deal Done!" only after payment, otherwise show "Deal Closed!"
                        isPaid ? tr('deal_done_congrats') : tr('deal_closed'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: isPaid
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trArgs('closed_deal_summary', {
                          'quantity': closedDeal.quantity.toString(),
                          'price': closedDeal.pricePerTon.toString(),
                          'total': closedDeal.totalAmount.toString(),
                        }),
                        style: TextStyle(
                          color: isPaid
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (!isPaid)
                        Text(
                          tr('payment_pending'),
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Payment confirmation pending - show buttons
            // Info text
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.purple.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('pay_via_upi_confirm_below'),
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Payment confirmation status
            if (payerConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      tr('payment_sent'),
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            if (receiverConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      tr('payment_received'),
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Show appropriate confirmation button based on user's role in deal
            // Farmer = Receiver (gets money), coldStorageOwner/Vyapari = Payer (sends money)

            // Vyapari (buyer/coldStorageOwner) sees "I Paid" button
            if (!isUserFarmerInDeal && !payerConfirmed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConfirmingPayment
                      ? null
                      : () => _confirmPaymentSent(closedDeal.id),
                  icon: _isConfirmingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(
                    _isConfirmingPayment ? tr('confirming') : tr('i_paid'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConfirmingPayment
                        ? Colors.grey
                        : Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            // Farmer sees "I Received" button
            if (isUserFarmerInDeal && !receiverConfirmed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConfirmingPayment
                      ? null
                      : () => _confirmPaymentReceived(closedDeal.id),
                  icon: _isConfirmingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.account_balance_wallet, size: 18),
                  label: Text(
                    _isConfirmingPayment
                        ? tr('confirming')
                        : tr('i_received_payment'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConfirmingPayment
                        ? Colors.grey
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            // Farmer can send reminder to Vyapari if payment not made yet
            if (isUserFarmerInDeal && !payerConfirmed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _sendPaymentReminder(isReminderForPayment: true),
                    icon: const Icon(Icons.notifications_active, size: 18),
                    label: Text(
                      tr('send_payment_reminder'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(
                        color: Colors.orange.shade400,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

            // Show waiting message based on who has confirmed
            if (payerConfirmed && !receiverConfirmed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isUserFarmerInDeal
                                  ? tr('trader_paid_confirm_receipt')
                                  : tr('waiting_farmer_confirm_receipt'),
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Vyapari can send reminder to farmer to confirm receipt
                    if (!isUserFarmerInDeal)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _sendPaymentReminder(
                              isReminderForPayment: false,
                            ),
                            icon: const Icon(
                              Icons.notifications_active,
                              size: 16,
                            ),
                            label: Text(
                              tr('send_confirmation_reminder'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700,
                              side: BorderSide(
                                color: Colors.orange.shade400,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (!payerConfirmed && receiverConfirmed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isUserFarmerInDeal
                                  ? tr('waiting_trader_confirm_payment')
                                  : tr('farmer_confirmed_confirm_payment'),
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Farmer can send reminder to Vyapari to confirm payment
                    if (isUserFarmerInDeal)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _sendPaymentReminder(
                              isReminderForPayment: true,
                            ),
                            icon: const Icon(
                              Icons.notifications_active,
                              size: 16,
                            ),
                            label: Text(
                              tr('send_payment_reminder'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700,
                              side: BorderSide(
                                color: Colors.orange.shade400,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    // No active deal - show propose deal button
    // NOTE: Propose Deal button commented out — deals are now made via chat only
    return const SizedBox.shrink();
    // return Container(
    //   margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    //   child: ElevatedButton.icon(
    //     onPressed: _isProposingDeal ? null : _showProposeDealDialog,
    //     icon: _isProposingDeal
    //         ? const SizedBox(
    //             width: 20,
    //             height: 20,
    //             child: CircularProgressIndicator(
    //               strokeWidth: 2,
    //               color: Colors.white,
    //             ),
    //           )
    //         : const Icon(Icons.handshake, size: 20, color: Colors.white),
    //     label: Text(
    //       _isProposingDeal ? tr('sending_proposal') : tr('propose_deal'),
    //       style: const TextStyle(
    //         fontSize: 15,
    //         fontWeight: FontWeight.w600,
    //         color: Colors.white,
    //       ),
    //     ),
    //     style: ElevatedButton.styleFrom(
    //       backgroundColor: AppColors.primaryGreen,
    //       elevation: 3,
    //       shadowColor: AppColors.primaryGreen.withOpacity(0.4),
    //       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    //       shape: RoundedRectangleBorder(
    //         borderRadius: BorderRadius.circular(12),
    //       ),
    //     ),
    //   ),
    // );
  }

  // Show dialog to propose a new deal
  void _showProposeDealDialog() {
    // Auto-fill quantity and price if available
    final quantityController = TextEditingController(
      text: widget.initialQuantity != null
          ? widget.initialQuantity!.toStringAsFixed(0)
          : '',
    );
    final priceController = TextEditingController(
      text: widget.initialPrice != null
          ? widget.initialPrice!.toStringAsFixed(0)
          : '',
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('propose_new_deal')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('quantity_in_packets'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.inventory),
                  hintText: tr('enter_quantity_deal'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('price_per_packet'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.currency_rupee),
                  hintText: tr('enter_price_deal'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('notes_optional'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.note),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              final price = double.tryParse(priceController.text);

              if (quantity == null || price == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('enter_valid_qty_price'))),
                );
                return;
              }

              Navigator.pop(context);
              await _proposeDeal(quantity, price, 1, notesController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: Text(
              tr('propose'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // Propose a deal
  Future<void> _proposeDeal(
    double quantity,
    double price,
    int duration,
    String notes,
  ) async {
    if (_isProposingDeal) return;
    setState(() => _isProposingDeal = true);
    try {
      final deal = await _dealService.proposeDeal(
        conversationId: widget.conversationId,
        quantity: quantity,
        pricePerTon: price,
        duration: duration,
        notes: notes.isEmpty ? null : notes,
      );

      setState(() {
        _deals.add(deal);
      });

      // Reload messages to see the deal message
      await _loadMessages();

      if (mounted) {
        // Show success dialog with green theme
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  tr('deal_request_sent'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5A27),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('deal_proposal_sent_msg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        trArgs('deal_preview_line', {
                          'quantity': quantity.toStringAsFixed(0),
                          'price': price.toStringAsFixed(0),
                        }),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        trArgs('deal_preview_total', {
                          'total': (quantity * price).toStringAsFixed(0),
                        }),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5A27),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      tr('ok_btn'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Propose deal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trArgs('failed_propose_deal', {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProposingDeal = false);
    }
  }

  // Confirm a deal - with confirmation dialog
  Future<void> _confirmDeal(String dealId) async {
    // Prevent double click
    if (_isConfirmingDeal) return;

    // Get the deal to show details
    final deal = _deals.firstWhere(
      (d) => d.id == dealId,
      orElse: () => _deals.first,
    );

    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.handshake, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('confirm_deal_q'),
                style: TextStyle(color: Colors.green.shade700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trArgs('deal_preview_line', {
                      'quantity': deal.quantity.toStringAsFixed(0),
                      'price': deal.pricePerTon.toStringAsFixed(0),
                    }),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trArgs('deal_total_amount', {
                      'amount': deal.totalAmount.toStringAsFixed(0),
                    }),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('confirm_deal_warning'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr('cancel_btn'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: Text(tr('yes_confirm')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Set loading state
    setState(() => _isConfirmingDeal = true);

    try {
      final updatedDeal = await _dealService.confirmDeal(dealId);

      setState(() {
        final index = _deals.indexWhere((d) => d.id == dealId);
        if (index != -1) {
          _deals[index] = updatedDeal;
        }
        _isConfirmingDeal = false;
      });

      await _loadMessages();

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  updatedDeal.isClosed
                      ? tr('deal_confirmed_celebration')
                      : tr('your_confirmation_done'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  updatedDeal.isClosed
                      ? tr('both_confirmed_proceed_payment')
                      : tr('waiting_other_party_confirm'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      tr('ok_btn'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isConfirmingDeal = false);
      debugPrint('Confirm deal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trArgs('failed_to_confirm_err', {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Cancel a deal - with confirmation dialog
  Future<void> _cancelDeal(String dealId) async {
    if (_isCancellingDeal) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('cancel_deal_q'),
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
        content: Text(
          tr('cancel_deal_confirm_msg'),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('no_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('yes_cancel')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancellingDeal = true);

    try {
      await _dealService.cancelDeal(dealId);

      setState(() {
        _deals.removeWhere((d) => d.id == dealId);
        _isCancellingDeal = false;
      });

      await _loadMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('deal_cancelled')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCancellingDeal = false);
      debugPrint('Cancel deal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trArgs('failed_to_cancel_err', {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Request payment from vendor (farmer action)
  Future<void> _requestPayment(String dealId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('request_payment')),
        content: Text(tr('request_payment_confirm_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(tr('send_request')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _paymentService.createPaymentOrder(dealId);

      if (result['success'] == true) {
        // Reload deals to update UI
        await _loadDeals();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('payment_request_sent')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to request payment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trArgs('payment_request_failed', {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show payment dialog for vendor
  Future<void> _showPaymentDialog(Deal deal) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('make_payment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('deal_details_label'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('${tr('quantity_label')}: ${deal.quantity} ${tr('packets')}'),
            Text(
              '${tr('rate_label')}: ₹${deal.pricePerTon.toStringAsFixed(2)}',
            ),
            const Divider(),
            Text(
              '${tr('total_amount_label')}: ₹${deal.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('razorpay_redirect_note'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _initiateRazorpayPayment(deal);
            },
            icon: const Icon(Icons.payment),
            label: Text(tr('pay_now_btn')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  // Initiate Razorpay payment
  Future<void> _initiateRazorpayPayment(Deal deal) async {
    try {
      // Get Razorpay key
      final keyResult = await _paymentService.getRazorpayKey();
      if (keyResult['success'] != true) {
        throw Exception('Failed to get payment key');
      }
      final razorpayKey = keyResult['key'];

      // Show payment in progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('initiating_razorpay')),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // For now, we'll show a simulated payment flow
      // In production, you would use the razorpay_flutter package
      final paymentConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Image.network(
                'https://razorpay.com/favicon.png',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.payment, color: Colors.blue),
              ),
              const SizedBox(width: 8),
              const Text('Razorpay'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '₹${deal.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('deal_payment'),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(tr('click_pay_to_confirm'), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel_btn')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(tr('pay_btn')),
            ),
          ],
        ),
      );

      if (paymentConfirmed == true) {
        // Simulate payment verification
        // In production, you would get these values from Razorpay callback
        final mockPaymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';
        final mockSignature = 'sig_${DateTime.now().millisecondsSinceEpoch}';

        final verifyResult = await _paymentService.verifyPayment(
          orderId: deal.paymentOrderId ?? '',
          paymentId: mockPaymentId,
          signature: mockSignature,
          dealId: deal.id,
        );

        if (verifyResult['success'] == true) {
          await _loadDeals();
          await _loadMessages(); // Reload messages to show "Deal Done!" message

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('deal_done_payment_success')),
                backgroundColor: Colors.green,
              ),
            );

            // Show receipt after successful payment
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              await showReceiptDialog(context, dealId: deal.id);
            }
          }
        } else {
          throw Exception(
            verifyResult['message'] ?? 'Payment verification failed',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trArgs('payment_failed_error', {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // View receipt for a deal
  Future<void> _viewReceipt(String dealId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // First try to get existing receipt
      var result = await _receiptService.getReceiptByDealId(dealId);

      // If no receipt exists, generate one
      if (result['success'] != true) {
        result = await _receiptService.generateReceipt(dealId);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
      }

      if (result['success'] == true && result['receipt'] != null) {
        if (mounted) {
          await showReceiptDialog(context, dealId: dealId);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('failed_load_receipt')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trArgs('generic_error', {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserInfoHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getRoleColor(
                  widget.otherUser.role,
                ).withOpacity(0.2),
                child: Icon(
                  _getRoleIcon(widget.otherUser.role),
                  color: _getRoleColor(widget.otherUser.role),
                  size: 20,
                ),
              ),
              // Online indicator
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isOtherUserOnline ? Colors.green : Colors.grey,
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
                        widget.otherUser.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (_isOtherUserTyping)
                  Row(
                    children: [
                      Text(
                        'typing',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryGreen,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 20,
                        height: 12,
                        child: _buildTypingDots(),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(
                            widget.otherUser.role,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.otherUser.roleDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            color: _getRoleColor(widget.otherUser.role),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOtherUserOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isOtherUserOnline
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 150)),
          builder: (context, value, child) {
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.5 + (value * 0.5)),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.otherUser.firstName}',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.sender.id == _currentUserId;

        // Show date separator
        bool showDate = false;
        if (index == 0) {
          showDate = true;
        } else {
          final prevMessage = _messages[index - 1];
          final prevDate = DateTime(
            prevMessage.createdAt.year,
            prevMessage.createdAt.month,
            prevMessage.createdAt.day,
          );
          final currDate = DateTime(
            message.createdAt.year,
            message.createdAt.month,
            message.createdAt.day,
          );
          showDate = prevDate != currDate;
        }

        return Column(
          children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDate(message.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    // Render special card for closing_call messages
    if (message.messageType == 'closing_call') {
      return _buildClosingCallCard(message, isMe);
    }
    // Render special card for closing_call_accepted messages
    if (message.messageType == 'closing_call_accepted') {
      return _buildClosingCallAcceptedCard(message, isMe);
    }
    // Render special card for deal_closed messages
    if (message.messageType == 'deal_closed') {
      return _buildDealClosedCard(message, isMe);
    }
    // Render special card for payment_shared messages
    if (message.messageType == 'payment_shared') {
      return _buildPaymentSharedCard(message, isMe);
    }
    // Render special card for payment_sent (buyer confirmed payment)
    if (message.messageType == 'payment_sent') {
      return _buildPaymentSentCard(message, isMe);
    }

    // Check if this is an image message
    final isImageMessage = message.messageType == 'image';

    // Distinct bubble colors for sender vs receiver
    final bubbleColor = isMe
        ? const Color(0xFFDCF8C6) // WhatsApp-style light green for sender
        : Colors.white; // White for receiver
    final textColor = Colors.black87; // Dark text for both (good readability)
    final timeColor = isMe ? Colors.grey[600] : Colors.grey[500];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: isImageMessage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (isImageMessage)
              _buildImageContent(message, isMe)
            else
              Text(
                message.content,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            const SizedBox(height: 4),
            Padding(
              padding: isImageMessage
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(color: timeColor, fontSize: 11),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build "Closing Call" card (Image 1 & 2 from UI)
  Widget _buildClosingCallCard(Message message, bool isMe) {
    final details = message.dealDetails;
    final sellerName = details?.sellerName ?? '';
    final buyerName = details?.buyerName ?? '';
    final quantity = details?.quantity?.toStringAsFixed(0) ?? '0';
    final price = details?.pricePerKg?.toStringAsFixed(0) ?? '0';
    final totalAmount =
        (details?.quantity != null && details?.pricePerKg != null)
        ? (details!.quantity! * details.pricePerKg!).toStringAsFixed(0)
        : '0';
    final listingRefId = details?.listingRefId ?? widget.listingRefId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Text('🤝', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    tr('closing_call'),
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seller
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('seller')} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          sellerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Buyer
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('buyer')} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          buyerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Quantity
                  Row(
                    children: [
                      const Text('🥔', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('quantity')} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$quantity kg',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price per kg
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('price')}: ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹$price/kg',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Total Price
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('total_price')}: ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹$totalAmount',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Listing Reference ID
                  if (listingRefId != null && listingRefId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('listing_id')}: ',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          listingRefId,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Action buttons for receiver only
            if (!isMe)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: _processedMessageIds.contains(message.id)
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tr('response_submitted'),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          // Cancel button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await _handleClosingCallCancel(message);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade400),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                tr('cancel'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Accept button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _handleClosingCallAccept(message);
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(
                                tr('accept'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build "Closing Call Accepted" card
  /// - Seller sees: "Share Payment Details" button
  /// - Buyer sees: "Waiting for seller to share payment details..."
  Widget _buildClosingCallAcceptedCard(Message message, bool isMe) {
    final details = message.dealDetails;
    final sellerName = details?.sellerName ?? '';
    final buyerName = details?.buyerName ?? '';
    final quantity = details?.quantity?.toStringAsFixed(0) ?? '0';
    final price = details?.pricePerKg?.toStringAsFixed(0) ?? '0';
    final total = details?.totalAmount?.toStringAsFixed(0) ?? '0';
    final listingRefId = details?.listingRefId ?? widget.listingRefId;

    // Determine if the current user is the seller
    final isSeller =
        _currentUserName == sellerName ||
        (_currentUserRole == 'farmer' && sellerName.isNotEmpty);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.shade400, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.teal.shade500,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('deal_terms_accepted'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Deal details
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🥔', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        '$quantity kg @ ₹$price/kg',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('total_amount_label')}: ₹$total',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Listing Reference ID
                  if (listingRefId != null && listingRefId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('listing')}: $listingRefId',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (isSeller && !isMe)
                    // Seller (who didn't send this message) sees "Share Payment Details" button
                    _processedMessageIds.contains(message.id)
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tr('response_submitted'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _handleSharePaymentDetails(message);
                              },
                              icon: const Icon(Icons.payment, size: 18),
                              label: Text(
                                tr('share_payment_details'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                            ),
                          )
                  else if (isSeller && isMe)
                    // Seller sent this message (shouldn't normally happen, but handle)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('share_payment_details_hint'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Buyer sees waiting message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('waiting_for_payment_details'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build "Deal Closed!" card (final state — no action buttons)
  Widget _buildDealClosedCard(Message message, bool isMe) {
    final details = message.dealDetails;
    final sellerName = details?.sellerName ?? '';
    final buyerName = details?.buyerName ?? '';
    final quantity = details?.quantity?.toStringAsFixed(0) ?? '0';
    final price = details?.pricePerKg?.toStringAsFixed(0) ?? '0';
    final totalAmount = (details?.quantity ?? 0) * (details?.pricePerKg ?? 0);
    final total =
        details?.totalAmount?.toStringAsFixed(0) ??
        totalAmount.toStringAsFixed(0);
    final listingRefId = details?.listingRefId ?? widget.listingRefId;

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Aloo Market Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo.png',
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storefront,
                    size: 35,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Deal Closed! Title
            Text(
              tr('deal_closed_title'),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D5A27),
              ),
            ),
            const SizedBox(height: 4),
            // Celebration icon
            const Text('🎉', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 12),
            // Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.amber.shade400,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('seller')} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          sellerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('buyer')} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          buyerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('🥔', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('quantity')} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$quantity kg',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('price')}: ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹$price/kg',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('total_price')}: ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '₹$total',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Listing Reference ID
                  if (listingRefId != null && listingRefId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('listing_id')}: ',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          listingRefId,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build "Payment Shared" card — Seller shared payment details
  /// - Buyer sees "I Have Paid" button
  /// - Seller sees "Waiting for buyer to pay..."
  Widget _buildPaymentSharedCard(Message message, bool isMe) {
    final details = message.dealDetails;
    final sellerName = details?.sellerName ?? '';
    final quantity = details?.quantity?.toStringAsFixed(0) ?? '0';
    final price = details?.pricePerKg?.toStringAsFixed(0) ?? '0';
    final total = details?.totalAmount?.toStringAsFixed(0) ?? '0';
    final listingRefId = details?.listingRefId ?? widget.listingRefId;

    // Determine if current user is the buyer
    final isBuyer =
        _currentUserName != sellerName && _currentUserRole != 'farmer';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade400, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade500,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Text('💳', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('payment_details_shared'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🥔', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        '$quantity kg @ ₹$price/kg',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('total_amount_label')}: ₹$total',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Listing Reference ID
                  if (listingRefId != null && listingRefId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('listing')}: $listingRefId',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (isBuyer && !isMe)
                    // Buyer (receiver of this message) sees "I Have Paid" button
                    _processedMessageIds.contains(message.id)
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Response submitted',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Text(
                                tr('seller_payment_details_hint'),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await _handleBuyerConfirmPaid(message);
                                  },
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                  ),
                                  label: Text(
                                    tr('i_have_paid'),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],
                          )
                  else
                    // Seller sees waiting message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('waiting_for_buyer_to_pay'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build "Payment Sent" card — Buyer confirmed payment
  /// - Seller sees "Confirm Received" / "Not Received" buttons
  /// - Buyer sees "Waiting for seller to confirm..."
  Widget _buildPaymentSentCard(Message message, bool isMe) {
    final details = message.dealDetails;
    final sellerName = details?.sellerName ?? '';
    final quantity = details?.quantity?.toStringAsFixed(0) ?? '0';
    final price = details?.pricePerKg?.toStringAsFixed(0) ?? '0';
    final total = details?.totalAmount?.toStringAsFixed(0) ?? '0';
    final listingRefId = details?.listingRefId ?? widget.listingRefId;

    // Determine if current user is the seller
    final isSeller =
        _currentUserName == sellerName ||
        (_currentUserRole == 'farmer' && sellerName.isNotEmpty);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.purple.shade500,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Text('💸', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('payment_sent_by_buyer'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🥔', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        '$quantity kg @ ₹$price/kg',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('total_amount_label')}: ₹$total',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Listing Reference ID
                  if (listingRefId != null && listingRefId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('listing')}: $listingRefId',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (isSeller && !isMe)
                    // Seller sees confirm/not received buttons
                    _processedMessageIds.contains(message.id)
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Response submitted',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Text(
                                tr('buyer_paid_conf_hint'),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await _handlePaymentNotReceived(
                                          message,
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        side: BorderSide(
                                          color: Colors.red.shade400,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        tr('not_received'),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await _handleConfirmPaymentReceived(
                                          message,
                                        );
                                      },
                                      icon: const Icon(Icons.check, size: 18),
                                      label: Text(
                                        tr('received'),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                  else
                    // Buyer sees waiting message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('waiting_for_seller_to_confirm_pay'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle Cancel on Closing Call card
  Future<void> _handleClosingCallCancel(Message message) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('cancel_deal_q'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          tr('cancel_deal_hint'),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('go_back'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cancel, size: 18),
            label: Text(tr('yes_cancel_deal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mark as processed ONLY after user confirmed
    setState(() => _processedMessageIds.add(message.id));

    try {
      await _chatService.sendMessage(
        widget.conversationId,
        tr('deal_cancelled_msg'),
      );
      await _loadMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle Accept on Closing Call card — sends closing_call_accepted
  Future<void> _handleClosingCallAccept(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.handshake,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('accept_deal_terms_q'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('agreeing_to_deal_hint'),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🥔 ${tr('quantity')} ${message.dealDetails?.quantity?.toStringAsFixed(0) ?? '0'} kg',
                  ),
                  Text(
                    '💰 ${tr('price')}: ₹${message.dealDetails?.pricePerKg?.toStringAsFixed(0) ?? '0'}/kg',
                  ),
                  Text(
                    '💵 ${tr('total_price')}: ₹${message.dealDetails?.totalAmount?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: Text(tr('yes_accept')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mark as processed ONLY after user confirmed
    setState(() => _processedMessageIds.add(message.id));

    try {
      final details = message.dealDetails;
      final msg = await _chatService.sendMessage(
        widget.conversationId,
        tr('deal_terms_accepted_msg'),
        messageType: 'closing_call_accepted',
        dealDetailsMap: {
          'quantity': details?.quantity,
          'pricePerKg': details?.pricePerKg,
          'totalAmount': details?.totalAmount,
          'sellerName': details?.sellerName,
          'buyerName': details?.buyerName,
          if (details?.listingRefId != null)
            'listingRefId': details!.listingRefId,
        },
      );
      setState(() {
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
      });
      await _loadMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Handle "Share Payment Details" on closing_call_accepted card (Seller only)
  Future<void> _handleSharePaymentDetails(Message message) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payment, color: Colors.teal.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('share_payment_details_q'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          tr('share_payment_details_modal_hint'),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('not_now'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: Text(tr('yes_accept')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mark as processed ONLY after user confirmed
    setState(() => _processedMessageIds.add(message.id));

    // Store deal details so we can attach them to the payment_shared card
    _pendingClosingCallDetails = message.dealDetails;
    _showPaymentOptionsSheetForSeller();
  }

  /// Payment options sheet — Seller shares UPI/QR/Passbook so Buyer can pay
  void _showPaymentOptionsSheetForSeller() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('share_payment_details_title'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Share UPI ID option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.green.shade700,
                ),
              ),
              title: Text(tr('send_upi_id')),
              subtitle: Text(tr('type_upi_address')),
              onTap: () {
                Navigator.pop(context);
                _showUpiIdDialogWithClosingCall();
              },
            ),
            const Divider(),
            // Share QR Code option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.qr_code, color: Colors.blue.shade700),
              ),
              title: Text(tr('send_qr_code')),
              subtitle: Text(tr('share_qr_image')),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendQrCodeWithClosingCall();
              },
            ),
            const Divider(),
            // Share Passbook first page option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.menu_book, color: Colors.orange.shade700),
              ),
              title: Text(tr('send_passbook_first_page')),
              subtitle: Text(tr('share_bank_passbook_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendPassbookWithClosingCall();
              },
            ),
          ],
        ),
      ),
    );
  }

  // UPI ID dialog for closing call pay flow
  void _showUpiIdDialogWithClosingCall() {
    final upiController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.account_balance, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Text(tr('send_upi_id')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: upiController,
              decoration: InputDecoration(
                labelText: tr('your_upi_id'),
                hintText: 'name@upi / 9876543210@paytm',
                prefixIcon: const Icon(Icons.payment),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final upiId = upiController.text.trim();
              if (upiId.isNotEmpty) {
                Navigator.pop(context);
                _sendUpiAndPaymentShared(upiId);
              }
            },
            icon: const Icon(Icons.send, size: 18),
            label: Text(tr('send_btn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Send UPI ID then send payment_shared card
  Future<void> _sendUpiAndPaymentShared(String upiId) async {
    final content = trArgs('my_upi_id_msg', {'upiId': upiId});
    setState(() => _isSending = true);
    try {
      // Send UPI message first
      final msg = await _chatService.sendMessage(
        widget.conversationId,
        content,
      );
      setState(() {
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
      });
      // Then send payment_shared card
      await _sendPaymentSharedCard();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_to_send')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pick QR code then send payment_shared card
  Future<void> _pickAndSendQrCodeWithClosingCall() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() => _isSending = true);
        final imageBytes = await image.readAsBytes();
        final msg = await _chatService.sendImageMessage(
          widget.conversationId,
          imageBytes.toList(),
          caption: tr('qr_code_for_payment'),
        );
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
        });
        await _sendPaymentSharedCard();
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_send_qr')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pick passbook then send payment_shared card
  Future<void> _pickAndSendPassbookWithClosingCall() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.orange.shade700),
              title: Text(tr('take_photo_camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.orange.shade700),
              title: Text(tr('choose_from_gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _isSending = true);
        final imageBytes = await image.readAsBytes();
        final msg = await _chatService.sendImageMessage(
          widget.conversationId,
          imageBytes.toList(),
          caption: tr('passbook_first_page_caption'),
        );
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
        });
        await _sendPaymentSharedCard();
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_send_passbook')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send payment_shared card — Seller shares payment details, Buyer will see "I Have Paid"
  Future<void> _sendPaymentSharedCard() async {
    try {
      final details = _pendingClosingCallDetails;
      final msg = await _chatService.sendMessage(
        widget.conversationId,
        '💳 Payment details shared. Please make the payment.',
        messageType: 'payment_shared',
        dealDetailsMap: {
          'quantity': details?.quantity,
          'pricePerKg': details?.pricePerKg,
          'totalAmount': details?.totalAmount,
          'sellerName': details?.sellerName,
          'buyerName': details?.buyerName,
          if (details?.listingRefId != null)
            'listingRefId': details!.listingRefId,
        },
      );
      setState(() {
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
      _pendingClosingCallDetails = null;
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Handle "I Have Paid" on payment_shared card (Buyer only) — sends payment_sent card
  Future<void> _handleBuyerConfirmPaid(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payment,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirm Payment Sent?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have you completed the payment of ₹${message.dealDetails?.totalAmount?.toStringAsFixed(0) ?? '0'}?',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only confirm if you have already sent the payment.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not Yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Yes, I Paid'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mark as processed ONLY after user confirmed
    setState(() => _processedMessageIds.add(message.id));

    try {
      final details = message.dealDetails;
      final msg = await _chatService.sendMessage(
        widget.conversationId,
        '💸 Payment sent! Waiting for seller to confirm receipt.',
        messageType: 'payment_sent',
        dealDetailsMap: {
          'quantity': details?.quantity,
          'pricePerKg': details?.pricePerKg,
          'totalAmount': details?.totalAmount,
          'sellerName': details?.sellerName,
          'buyerName': details?.buyerName,
          if (details?.listingRefId != null)
            'listingRefId': details!.listingRefId,
        },
      );
      setState(() {
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
      });
      await _loadMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Handle "Confirm Received" on payment_sent card (Seller only) — sends deal_closed
  Future<void> _handleConfirmPaymentReceived(Message message) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirm Payment Received?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Have you received the payment? Once confirmed, the deal will be marked as closed.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not Yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Yes, Received'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mark as processed ONLY after user confirmed
    setState(() => _processedMessageIds.add(message.id));

    try {
      final details = message.dealDetails;
      await _chatService.sendMessage(
        widget.conversationId,
        'Deal Closed! 🎉',
        messageType: 'deal_closed',
        dealDetailsMap: {
          'quantity': details?.quantity,
          'pricePerKg': details?.pricePerKg,
          'totalAmount': details?.totalAmount,
          'sellerName': details?.sellerName,
          'buyerName': details?.buyerName,
          if (details?.listingRefId != null)
            'listingRefId': details!.listingRefId,
        },
      );
      await _loadMessages();
      _scrollToBottom();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deal closed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Handle "Not Received" on payment_shared card
  Future<void> _handlePaymentNotReceived(Message message) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.money_off,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Payment Not Received?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure the payment has not been received? The buyer will be notified to check and resend.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Go Back',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.warning_amber, size: 18),
            label: const Text('Yes, Not Received'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Mark as processed ONLY after user confirmed
    setState(() => _processedMessageIds.add(message.id));

    try {
      await _chatService.sendMessage(
        widget.conversationId,
        '⚠️ Payment not received yet. Please check and resend.',
      );
      await _loadMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Build image content for image messages
  Widget _buildImageContent(Message message, bool isMe) {
    try {
      // Parse the JSON content
      final contentData = json.decode(message.content);
      final String? base64Image = contentData['imageData'];
      final String? caption = contentData['caption'];

      if (base64Image == null || base64Image.isEmpty) {
        return Text(
          caption ?? tr('image_label'),
          style: const TextStyle(color: Colors.black87),
        );
      }

      return Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Image with tap to view full screen
          GestureDetector(
            onTap: () => _showFullScreenImage(base64Image, caption),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(base64Image),
                width: 250,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 150,
                    color: Colors.grey.shade300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('image_failed_to_load'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Caption if present
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
              child: Text(
                caption,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
        ],
      );
    } catch (e) {
      // If parsing fails, show the content as text
      return Text(
        message.content,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
      );
    }
  }

  /// Show full screen image viewer
  void _showFullScreenImage(String base64Image, String? caption) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full screen image with zoom
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Caption at bottom
            if (caption != null && caption.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(Message message) {
    // Status: sent -> delivered -> read
    final status = message.status ?? (message.isRead ? 'read' : 'sent');

    IconData icon;
    Color color;

    switch (status) {
      case 'read':
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case 'delivered':
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case 'sent':
      default:
        icon = Icons.done;
        color = Colors.grey;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(color: Color(0xFFE9F8C9)),
      child: SafeArea(
        child: Row(
          children: [
            // UPI/Payment Share Button
            Container(
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.currency_rupee,
                  color: Colors.purple.shade700,
                  size: 22,
                ),
                onPressed: _showPaymentOptionsSheet,
                tooltip: tr('share_payment_details'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                onChanged: (_) => _onTyping(),
                decoration: InputDecoration(
                  hintText: tr('type_a_message'),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show Closing Call dialog (Image 1 from UI)
  void _showClosingCallDialog() {
    final quantityController = TextEditingController(
      text: widget.initialQuantity != null
          ? widget.initialQuantity!.toStringAsFixed(0)
          : '',
    );
    final priceController = TextEditingController(
      text: widget.initialPrice != null
          ? widget.initialPrice!.toStringAsFixed(0)
          : '',
    );

    // Determine seller/buyer names
    final currentName = _currentUserName ?? 'You';
    final otherName = widget.otherUser.fullName;

    // Farmer is seller, other is buyer (or vice versa based on role)
    String sellerName;
    String buyerName;
    if (_currentUserRole == 'farmer') {
      sellerName = currentName;
      buyerName = otherName;
    } else if (widget.otherUser.role == 'farmer') {
      sellerName = otherName;
      buyerName = currentName;
    } else {
      // Default: current user is seller
      sellerName = currentName;
      buyerName = otherName;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🤝', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('closing_call'),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D5A27),
                          ),
                        ),
                        if (widget.listingRefId != null &&
                            widget.listingRefId!.isNotEmpty)
                          Text(
                            'Listing: ${widget.listingRefId}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Seller & Buyer info (auto-filled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('seller')}: ',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            sellerName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${tr('buyer')}: ',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            buyerName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Quantity field
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '🥔  ${tr('quantity')} (kg)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.inventory_2),
                  hintText: tr('enter_quantity_in_kg'),
                ),
              ),
              const SizedBox(height: 14),
              // Negotiated Price field
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '💰  ${tr('negotiated_price')} (₹/kg)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.currency_rupee),
                  hintText: tr('enter_price_per_kg'),
                ),
              ),
              const SizedBox(height: 20),
              // Send Final Call button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final quantity = double.tryParse(
                      quantityController.text.trim(),
                    );
                    final price = double.tryParse(priceController.text.trim());
                    if (quantity == null ||
                        price == null ||
                        quantity <= 0 ||
                        price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter valid quantity and price',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _sendClosingCall(
                      quantity: quantity,
                      price: price,
                      sellerName: sellerName,
                      buyerName: buyerName,
                    );
                  },
                  icon: const Icon(Icons.send, size: 20),
                  label: Text(
                    tr('send_final_call'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Send a Closing Call message
  Future<void> _sendClosingCall({
    required double quantity,
    required double price,
    required String sellerName,
    required String buyerName,
  }) async {
    setState(() => _isSending = true);
    try {
      final totalAmount = quantity * price;
      final message = await _chatService.sendMessage(
        widget.conversationId,
        '🤝 Closing Call: $quantity kg @ ₹$price/kg = ₹${totalAmount.toStringAsFixed(0)}',
        messageType: 'closing_call',
        dealDetailsMap: {
          'quantity': quantity,
          'pricePerKg': price,
          'totalAmount': totalAmount,
          'sellerName': sellerName,
          'buyerName': buyerName,
          if (widget.listingRefId != null) 'listingRefId': widget.listingRefId,
        },
      );
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send closing call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show payment options bottom sheet
  void _showPaymentOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('share_payment_details_title'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Share UPI ID option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Colors.green.shade700,
                ),
              ),
              title: Text(tr('send_upi_id')),
              subtitle: Text(tr('type_upi_address')),
              onTap: () {
                Navigator.pop(context);
                _showUpiIdDialog();
              },
            ),
            const Divider(),
            // Share QR Code option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.qr_code, color: Colors.blue.shade700),
              ),
              title: Text(tr('send_qr_code')),
              subtitle: Text(tr('share_qr_image')),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendQrCode();
              },
            ),
            const Divider(),
            // Share Passbook first page option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.menu_book, color: Colors.orange.shade700),
              ),
              title: Text(tr('send_passbook_first_page')),
              subtitle: Text(tr('share_bank_passbook_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendPassbookImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show UPI ID input dialog
  void _showUpiIdDialog() {
    final upiController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.account_balance, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Text(tr('send_upi_id')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: upiController,
              decoration: InputDecoration(
                labelText: tr('your_upi_id'),
                hintText: 'name@upi / 9876543210@paytm',
                prefixIcon: const Icon(Icons.payment),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            Text(
              tr('upi_example_hint'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel_btn')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final upiId = upiController.text.trim();
              if (upiId.isNotEmpty) {
                Navigator.pop(context);
                _sendUpiMessage(upiId);
              }
            },
            icon: const Icon(Icons.send, size: 18),
            label: Text(tr('send_btn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Send UPI ID as a formatted message
  Future<void> _sendUpiMessage(String upiId) async {
    final content = trArgs('my_upi_id_msg', {'upiId': upiId});

    setState(() => _isSending = true);
    try {
      final message = await _chatService.sendMessage(
        widget.conversationId,
        content,
        messageType: 'text',
      );
      setState(() {
        // Avoid duplicate if polling already added this message
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('failed_to_send'))));
      }
    }
  }

  // Pick and send QR code image
  Future<void> _pickAndSendQrCode() async {
    final picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90, // Higher quality for QR codes to be scannable
      );

      if (image != null) {
        setState(() => _isSending = true);

        // Read image bytes for both web and mobile
        final imageBytes = await image.readAsBytes();

        // Send image message with QR code caption
        final message = await _chatService.sendImageMessage(
          widget.conversationId,
          imageBytes.toList(),
          caption: tr('qr_code_for_payment'),
        );

        setState(() {
          // Avoid duplicate if polling already added this message
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
          }
          _isSending = false;
        });
        _scrollToBottom();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('qr_code_sent')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_send_qr')),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error sending QR code: $e');
    }
  }

  // Pick and send passbook first page image
  Future<void> _pickAndSendPassbookImage() async {
    final picker = ImagePicker();

    // Let user choose camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('choose_passbook_photo'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.orange.shade700),
              title: Text(tr('take_photo_camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.orange.shade700),
              title: Text(tr('choose_from_gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isSending = true);

        final imageBytes = await image.readAsBytes();

        final message = await _chatService.sendImageMessage(
          widget.conversationId,
          imageBytes.toList(),
          caption: tr('passbook_first_page_caption'),
        );

        setState(() {
          // Avoid duplicate if polling already added this message
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
          }
          _isSending = false;
        });
        _scrollToBottom();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('passbook_photo_sent')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_send_passbook')),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error sending passbook image: $e');
    }
  }

  // Confirm payment sent (payer's confirmation)
  Future<void> _confirmPaymentSent(String dealId) async {
    // Prevent double click
    if (_isConfirmingPayment) return;

    final closedDeal = _closedDeal;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send, color: Colors.blue.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('confirm_payment_sent'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('payment_amount'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '₹${closedDeal?.totalAmount ?? '0'}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('have_you_sent_payment'),
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('no_go_back'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: Text(tr('yes_i_paid')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isConfirmingPayment = true);

    try {
      final deal = await _dealService.confirmPaymentSent(dealId);

      setState(() {
        final index = _deals.indexWhere((d) => d.id == dealId);
        if (index != -1) {
          _deals[index] = deal;
        }
        _isConfirmingPayment = false;
      });

      await _loadMessages();

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('payment_confirmed'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              tr('payment_confirm_sent_waiting'),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr('ok_btn')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Confirm payment sent error: $e');
      setState(() => _isConfirmingPayment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Confirm payment received (receiver's confirmation)
  Future<void> _confirmPaymentReceived(String dealId) async {
    // Prevent double click
    if (_isConfirmingPayment) return;

    final closedDeal = _closedDeal;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('confirm_payment_received'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('payment_amount'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    '₹${closedDeal?.totalAmount ?? '0'}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('have_you_received_payment'),
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('no_go_back'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: Text(tr('yes_money_received')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isConfirmingPayment = true);

    try {
      final deal = await _dealService.confirmPaymentReceived(dealId);

      setState(() {
        final index = _deals.indexWhere((d) => d.id == dealId);
        if (index != -1) {
          _deals[index] = deal;
        }
        _isConfirmingPayment = false;
      });

      await _loadMessages();

      if (mounted) {
        // Show success dialog based on whether both confirmations are complete
        final isPaidNow = deal.paymentStatus == 'paid';

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPaidNow
                        ? Colors.green.shade100
                        : Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaidNow ? Icons.celebration : Icons.check_circle,
                    color: isPaidNow
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isPaidNow
                        ? tr('deal_complete')
                        : tr('payment_received_confirmed'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              isPaidNow
                  ? tr('both_confirmed_deal_complete')
                  : tr('your_confirm_sent_waiting_trader'),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaidNow
                      ? Colors.green.shade600
                      : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr('ok_btn')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Confirm payment received error: $e');
      setState(() => _isConfirmingPayment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Send payment reminder to the other party
  Future<void> _sendPaymentReminder({
    required bool isReminderForPayment,
  }) async {
    try {
      String reminderMessage;

      if (isReminderForPayment) {
        // Reminder for Vyapari to make payment
        reminderMessage = tr('payment_reminder_msg');
      } else {
        // Reminder for confirming payment (either sent or received)
        reminderMessage = tr('confirm_reminder_msg');
      }

      // Send the reminder as a chat message
      final message = await _chatService.sendMessage(
        widget.conversationId,
        reminderMessage,
      );

      setState(() {
        // Avoid duplicate if polling already added this message
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
      });
      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('reminder_sent')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Send payment reminder error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_send_reminder')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
