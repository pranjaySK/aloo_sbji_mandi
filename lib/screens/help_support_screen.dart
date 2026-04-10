import 'package:aloo_sbji_mandi/core/service/auth_service.dart';
import 'package:aloo_sbji_mandi/core/service/farmer_chatbot_service.dart';
import 'package:aloo_sbji_mandi/core/service/feedback_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await AuthService().getCurrentUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@aloosbjimandi.com',
      query: 'subject=Help Request',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: '+911234567890');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: CustomRoundedAppBar(title: tr('help_and_support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryGreen, Color(0xFF1B7A3D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('how_can_we_help'),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('contact_us_for_help'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // AI Chatbot Button
            GestureDetector(
              onTap: () => _openChatbot(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('ask_ai_assistant'),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('ask_anything'),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              tr('talk_to_us'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),

            _contactCard(
              icon: Icons.phone_outlined,
              title: tr('call_us'),
              subtitle: tr('call_us_subtitle'),
              onTap: _launchPhone,
            ),
            const SizedBox(height: 12),

            _contactCard(
              icon: Icons.chat_outlined,
              title: 'WhatsApp',
              subtitle: tr('whatsapp_subtitle'),
              onTap: () => _launchUrl('https://wa.me/911234567890'),
            ),

            const SizedBox(height: 24),

            Text(
              tr('common_questions'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),

            // Role-specific FAQ items
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
            else
              ..._getRoleSpecificFaqs(),

            const SizedBox(height: 24),

            // Feedback Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.feedback_outlined,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('give_feedback'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('feedback_description'),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      _showFeedbackDialog(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(tr('send_feedback')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// Returns role-specific FAQ items based on user role
  List<Widget> _getRoleSpecificFaqs() {
    // Common FAQs for all roles
    final commonFaqs = [
      _faqItem(
        question: tr('faq_how_to_use_app'),
        answer: tr('faq_how_to_use_app_answer'),
      ),
      _faqItem(
        question: tr('faq_how_to_change_profile'),
        answer: tr('faq_how_to_change_profile_answer'),
      ),
      _faqItem(
        question: tr('faq_how_to_change_language'),
        answer: tr('faq_how_to_change_language_answer'),
      ),
      _faqItem(
        question: tr('faq_any_problem'),
        answer: tr('faq_any_problem_answer'),
      ),
    ];

    // Role-specific FAQs
    switch (_userRole) {
      case 'farmer':
        return [
          _faqItem(
            question: tr('faq_how_to_sell_potato'),
            answer: tr('faq_how_to_sell_potato_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_book_cold_storage'),
            answer: tr('faq_how_to_book_cold_storage_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_talk_to_trader'),
            answer: tr('faq_how_to_talk_to_trader_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_make_deal'),
            answer: tr('faq_how_to_make_deal_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_see_bookings'),
            answer: tr('faq_how_to_see_bookings_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_check_mandi_prices'),
            answer: tr('faq_how_to_check_mandi_prices_answer'),
          ),
          _faqItem(
            question: tr('faq_what_is_ai_prediction'),
            answer: tr('faq_what_is_ai_prediction_answer'),
          ),
          ...commonFaqs,
        ];

      case 'vendor':
        return [
          _faqItem(
            question: tr('faq_how_to_buy_potato'),
            answer: tr('faq_how_to_buy_potato_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_create_buy_request'),
            answer: tr('faq_how_to_create_buy_request_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_talk_to_farmer'),
            answer: tr('faq_how_to_talk_to_farmer_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_accept_deal'),
            answer: tr('faq_how_to_accept_deal_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_make_payment'),
            answer: tr('faq_how_to_make_payment_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_see_buy_requests'),
            answer: tr('faq_how_to_see_buy_requests_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_check_mandi_prices'),
            answer: tr('faq_how_to_check_mandi_prices_answer'),
          ),
          ...commonFaqs,
        ];

      case 'cold-storage':
        return [
          _faqItem(
            question: tr('faq_how_to_add_storage'),
            answer: tr('faq_how_to_add_storage_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_see_booking_requests'),
            answer: tr('faq_how_to_see_booking_requests_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_update_storage'),
            answer: tr('faq_how_to_update_storage_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_manage_capacity'),
            answer: tr('faq_how_to_manage_capacity_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_receive_payment'),
            answer: tr('faq_how_to_receive_payment_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_delete_storage'),
            answer: tr('faq_how_to_delete_storage_answer'),
          ),
          _faqItem(
            question: tr('faq_how_to_set_pricing'),
            answer: tr('faq_how_to_set_pricing_answer'),
          ),
          ...commonFaqs,
        ];

      default:
        // Default FAQs if role is not detected
        return [
          _faqItem(
            question: tr('faq_how_to_check_mandi_prices'),
            answer: tr('faq_how_to_check_mandi_prices_answer'),
          ),
          _faqItem(
            question: tr('faq_what_is_ai_analysis'),
            answer: tr('faq_what_is_ai_analysis_answer'),
          ),
          ...commonFaqs,
        ];
    }
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _faqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        iconColor: AppColors.primaryGreen,
        collapsedIconColor: Colors.grey,
        children: [
          Text(
            answer,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    final feedbackService = FeedbackService();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('send_feedback')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: tr('feedback_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('feedback_sent_to_admin'),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('please_write_something')),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final result = await feedbackService.submitFeedback(
                        message: controller.text.trim(),
                        userRole: _userRole,
                      );

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['success']
                                ? tr('feedback_success')
                                : tr('feedback_error'),
                          ),
                          backgroundColor: result['success']
                              ? AppColors.primaryGreen
                              : Colors.red,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(tr('submit'), style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatbot(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FarmerChatbotScreen(isHindi: AppLocalizations.isHindi),
      ),
    );
  }
}

// ==================== CHATBOT SCREEN ====================
class FarmerChatbotScreen extends StatefulWidget {
  final bool isHindi;

  const FarmerChatbotScreen({super.key, required this.isHindi});

  @override
  State<FarmerChatbotScreen> createState() => _FarmerChatbotScreenState();
}

class _FarmerChatbotScreenState extends State<FarmerChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _addBotMessage(tr('chatbot_welcome'));
    _suggestions = [
      tr('chatbot_suggestion_sell'),
      tr('chatbot_suggestion_price'),
      tr('chatbot_suggestion_seed'),
    ];
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _messageController.clear();
    _scrollToBottom();

    // Get bot response
    Future.delayed(const Duration(milliseconds: 500), () {
      final response = FarmerChatbotService.getResponse(
        text,
        isHindi: widget.isHindi,
      );
      _addBotMessage(response.message);
      setState(() {
        _suggestions = response.suggestions;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ai_assistant'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  tr('always_online'),
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Suggestions
          if (_suggestions.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        _suggestions[index],
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue[50],
                      onPressed: () => _sendMessage(_suggestions[index]),
                    ),
                  );
                },
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: tr('type_your_question'),
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        filled: true,
                        fillColor: AppColors.inputFill(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _sendMessage(_messageController.text),
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.smart_toy, color: Colors.blue[700], size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[700] : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isUser ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
