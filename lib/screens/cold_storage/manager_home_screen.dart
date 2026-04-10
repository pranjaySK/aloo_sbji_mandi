import 'package:aloo_sbji_mandi/core/service/manager_service.dart';
import 'package:aloo_sbji_mandi/core/utils/custom_rounded_app_bar.dart';
import 'package:aloo_sbji_mandi/core/utils/role_shell_scroll_padding.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/booking_requests_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/manage_boli_alerts_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/token_system_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:aloo_sbji_mandi/widgets/common_widget.dart/custom_drawer_widget.dart';
import 'package:aloo_sbji_mandi/widgets/language_toggle_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  final ManagerService _managerService = ManagerService();
  Map<String, dynamic>? _coldStorage;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final result = await _managerService.getDashboard();
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _coldStorage = result['data']['coldStorage'];
        _stats = result['data']['stats'];
      }
    });
  }

  Future<void> _toggleAvailability() async {
    final result = await _managerService.toggleAvailability();
    if (result['success']) {
      _loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['data']?['coldStorage']?['isAvailable'] == true
                  ? 'Storage marked available / उपलब्ध'
                  : 'Storage marked unavailable / अनुपलब्ध',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: const CustomAppDrawer(),
      ),
      appBar: CustomRoundedAppBar(
        title: '',
        leadingIcon: Icons.menu,
        isDrawerIcon: true,
        actions: [
          const LanguageToggleWidget(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      backgroundColor: AppColors.scaffoldBg(context),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _coldStorage == null
          ? _buildNoStorageAssigned()
          : _buildManagerDashboard(),
    );
  }

  Widget _buildNoStorageAssigned() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warehouse_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No Cold Storage Assigned',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'कोई कोल्ड स्टोरेज असाइन नहीं है',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            Text(
              'The cold storage owner needs to assign you as a manager.\nकोल्ड स्टोरेज मालिक को आपको मैनेजर बनाना होगा।',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerDashboard() {
    final storageName = _coldStorage!['name'] ?? 'Cold Storage';
    final isAvailable = _coldStorage!['isAvailable'] ?? false;
    final totalCapacity =
        _stats?['totalCapacity'] ?? _coldStorage!['capacity'] ?? 0;
    final availableCapacity =
        _stats?['availableCapacity'] ?? _coldStorage!['availableCapacity'] ?? 0;
    final pricePerTon = _coldStorage!['pricePerTon'] ?? 0;
    final percentUsed =
        _stats?['percentUsed'] ??
        (totalCapacity > 0
            ? ((totalCapacity - availableCapacity) / totalCapacity * 100)
                  .toInt()
            : 0);
    final city = _coldStorage!['city'] ?? '';
    final state = _coldStorage!['state'] ?? '';
    final ownerInfo = _coldStorage!['owner'];
    final ownerName = ownerInfo != null
        ? '${ownerInfo['firstName'] ?? ''} ${ownerInfo['lastName'] ?? ''}'
              .trim()
        : 'Owner';

    // Booking stats from dashboard API
    final pendingBookings = _stats?['pendingBookings'] ?? 0;
    final acceptedBookings = _stats?['acceptedBookings'] ?? 0;
    final todayBookings = _stats?['todayBookings'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: RoleShellScrollPadding.managerHome,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Manager Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Manager / मैनेजर',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cold Storage Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppColors.primaryGreen.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          storageName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Colors.green.shade400
                              : Colors.red.shade400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAvailable
                              ? 'Available / उपलब्ध'
                              : 'Unavailable / अनुपलब्ध',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$city, $state',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Owner: $ownerName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats Row
                  Row(
                    children: [
                      _statBadge(
                        Icons.inventory_2,
                        '$totalCapacity',
                        'Total Pkt',
                      ),
                      const SizedBox(width: 12),
                      _statBadge(
                        Icons.check_circle,
                        '$availableCapacity',
                        'Available',
                      ),
                      const SizedBox(width: 12),
                      _statBadge(
                        Icons.currency_rupee,
                        '₹$pricePerTon',
                        'Price/Pkt',
                      ),
                      const SizedBox(width: 12),
                      _statBadge(Icons.pie_chart, '$percentUsed%', 'Used'),
                    ],
                  ),
                ],
              ),
            ),

            // Stats Row - Booking Stats
            const SizedBox(height: 16),
            Row(
              children: [
                _quickStatCard(
                  icon: Icons.pending_actions,
                  value: '$pendingBookings',
                  label: 'Pending\nपेंडिंग',
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _quickStatCard(
                  icon: Icons.check_circle,
                  value: '$acceptedBookings',
                  label: 'Accepted\nस्वीकृत',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _quickStatCard(
                  icon: Icons.today,
                  value: '$todayBookings',
                  label: 'Today\nआज',
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              'Manager Dashboard / मैनेजर डैशबोर्ड',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            // Booking Requests (Full Access)
            _buildDashboardCard(
              title: 'Booking Requests / बुकिंग रिक्वेस्ट',
              subtitle:
                  'View & respond to booking requests\nबुकिंग रिक्वेस्ट देखें और जवाब दें',
              icon: Icons.inbox,
              gradient: [Colors.orange.shade700, Colors.orange.shade500],
              badgeCount: pendingBookings > 0 ? pendingBookings : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const BookingRequestsScreen(isManagerView: false),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Boli Alert (Full Access)
            _buildDashboardCard(
              title: 'Boli Alert / बोली अलर्ट',
              subtitle:
                  'Create & manage auction alerts\nबोली अलर्ट बनाएं और प्रबंधित करें',
              icon: Icons.campaign,
              gradient: [Colors.purple.shade700, Colors.purple.shade500],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageBoliAlertsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Token System (Full Access)
            _buildDashboardCard(
              title: 'Token System / टोकन सिस्टम',
              subtitle: 'Manage farmer queue & tokens\nटोकन कतार प्रबंधित करें',
              icon: Icons.confirmation_number,
              gradient: [Colors.teal.shade700, Colors.teal.shade500],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TokenSystemScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Toggle Availability
            GestureDetector(
              onTap: _toggleAvailability,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAvailable
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAvailable ? Icons.toggle_on : Icons.toggle_off,
                      color: isAvailable ? Colors.green : Colors.red,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAvailable
                                ? 'Storage Available / स्टोरेज उपलब्ध'
                                : 'Storage Unavailable / स्टोरेज अनुपलब्ध',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isAvailable
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                          Text(
                            'Tap to toggle / बदलने के लिए टैप करें',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Space Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Space Status / स्पेस स्थिति',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentUsed / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentUsed > 80 ? Colors.red : Colors.green,
                      ),
                      minHeight: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Used: ${totalCapacity - availableCapacity} Pkt',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      Text(
                        'Available: $availableCapacity Pkt',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    String? badge,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
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
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (badgeCount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
