import 'package:aloo_sbji_mandi/core/service/fcm_service.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:aloo_sbji_mandi/core/service/local_notification_service.dart';
import 'package:aloo_sbji_mandi/core/service/socket_service.dart';
// Firebase imports — uncomment when google-services.json is added
// import 'package:aloo_sbji_mandi/core/service/fcm_service.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:aloo_sbji_mandi/screens/admin/admin_home_screen.dart';
import 'package:aloo_sbji_mandi/screens/advertise_with_us_screen.dart';
import 'package:aloo_sbji_mandi/screens/ai_crop_advisor_screen.dart';
import 'package:aloo_sbji_mandi/screens/aloo_mitra/aloo_mitra_home_screen.dart';
import 'package:aloo_sbji_mandi/screens/aloo_mitra/aloo_mitra_registration_screen.dart';
import 'package:aloo_sbji_mandi/screens/chat/chat_screen.dart';
import 'package:aloo_sbji_mandi/screens/chat/conversations_list_screen.dart';
import 'package:aloo_sbji_mandi/screens/chat/new_chat_screen.dart';
import 'package:aloo_sbji_mandi/screens/city_mandi_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/cold_storage_home_screen.dart';
import 'package:aloo_sbji_mandi/screens/cold_storage/cold_storage_notification_screen.dart';
import 'package:aloo_sbji_mandi/screens/create_availbility_screen.dart';
import 'package:aloo_sbji_mandi/screens/crop_analysis_screen.dart';

import 'package:aloo_sbji_mandi/screens/hire_rent_cold_storage_screen.dart';
import 'package:aloo_sbji_mandi/screens/splash_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/buy_sell_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/create_sell_request_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/my_token_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/seller_listing_screen.dart';
import 'package:aloo_sbji_mandi/screens/kishan/trader_requests_screen.dart';
import 'package:aloo_sbji_mandi/screens/kyc_documents_screen.dart';
import 'package:aloo_sbji_mandi/screens/mandi_price_screen.dart';
import 'package:aloo_sbji_mandi/screens/mandi_price_trend_screen.dart';
import 'package:aloo_sbji_mandi/screens/my_plan_screen.dart';
import 'package:aloo_sbji_mandi/screens/notification_screen.dart';
import 'package:aloo_sbji_mandi/screens/otp_login_screen.dart';
import 'package:aloo_sbji_mandi/screens/rent_storage_screen.dart';
import 'package:aloo_sbji_mandi/screens/settings_screen.dart';
import 'package:aloo_sbji_mandi/screens/sign_up_screen.dart';
import 'package:aloo_sbji_mandi/screens/storage_detail_screen.dart';
import 'package:aloo_sbji_mandi/screens/transaction_history_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/buy_potato_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/my_buy_requests_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/potato_detail_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/transport_service.dart';
import 'package:aloo_sbji_mandi/theme/theme_provider.dart';
import 'package:aloo_sbji_mandi/widgets/aloo_mitra/aloo_mitra_nav_bar_widget.dart';
import 'package:aloo_sbji_mandi/widgets/cold_storage/cold_storage_nav_bar_widget.dart';
import 'package:aloo_sbji_mandi/widgets/cold_storage/manager_nav_bar_widget.dart';
import 'package:aloo_sbji_mandi/widgets/kishan/kishan_nav_bar_widget.dart';
import 'package:aloo_sbji_mandi/widgets/vyapari/vyapari_nav_bar_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/kishan/kishan_home_screen.dart';
import 'screens/language_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow google_fonts to fetch fonts over HTTP (for web)
  GoogleFonts.config.allowRuntimeFetching = true;
  await dotenv.load(fileName: ".env");
  await AppLocalizations.init();
  
  bool firebaseReady = false;
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase init failed (non-fatal): $e');
    }
  }

  // Initialize notification service & boli alert listener (mobile only)
  if (!kIsWeb) {
    try {
      await LocalNotificationService().initialize();
      _setupBoliAlertNotifications();
      _setupTokenQueueNotifications();
      // FCM disabled until Firebase is configured
      if (firebaseReady) {
        await FCMService().initialize();
      }
    } catch (e) {
      debugPrint('Notification setup failed (non-fatal): $e');
    }
  }

  runApp(const MyApp());
}

/// Listen for boli_alert_reminder socket events and show local push notifications
void _setupBoliAlertNotifications() {
  final socketService = SocketService();
  socketService.addBoliAlertListener((data) {
    final title = data['title'] as String? ?? 'बोली अलर्ट / Boli Alert';
    final message = data['message'] as String? ?? 'Upcoming boli alert!';
    final boliAlertId = data['boliAlertId'] as String?;
    final coldStorageName = data['coldStorageName'] as String?;
    final boliTime = data['boliTime'] as String?;
    final city = data['city'] as String?;
    final daysBeforeLabel = data['daysBeforeLabel'] as String?;

    LocalNotificationService().showBoliAlertNotification(
      title: title,
      message: message,
      boliAlertId: boliAlertId,
      coldStorageName: coldStorageName,
      boliTime: boliTime,
      city: city,
      daysBeforeLabel: daysBeforeLabel,
    );
  });
}

/// Listen for token queue socket events and show local push notifications
void _setupTokenQueueNotifications() {
  final socketService = SocketService();

  // Map of token events to their notification titles
  const tokenEventTitles = {
    'token_called': 'आपकी बारी आ गई! / Your Turn!',
    'token_nearby': 'तैयार रहें / Get Ready!',
    'token_issued': 'टोकन जारी / Token Issued',
    'token_in_service': 'सेवा शुरू / Service Started',
    'token_completed': 'सेवा पूर्ण / Service Done',
    'token_skipped': 'टोकन छोड़ा गया / Token Skipped',
    'token_transferred': 'काउंटर बदला / Counter Changed',
    'token_rejected': 'टोकन अस्वीकार / Token Rejected',
  };

  socketService.addTokenEventListener((data) {
    final eventType = data['event'] as String? ?? '';
    final title = tokenEventTitles[eventType] ?? 'टोकन अपडेट / Token Update';
    final message =
        data['message'] as String? ?? 'Your token status has been updated.';
    final tokenId = data['tokenId']?.toString();
    final coldStorageName = data['coldStorageName'] as String?;

    LocalNotificationService().showTokenNotification(
      title: title,
      message: message,
      tokenId: tokenId,
      event: eventType,
      coldStorageName: coldStorageName,
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Static method to access the state from anywhere
  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeNotifier.instance;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    AppLocalizations.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    AppLocalizations.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
      // Force all elements in the tree to rebuild to pick up new static tr() values
      void rebuild(Element el) {
        el.markNeedsBuild();
        el.visitChildren(rebuild);
      }
      (context as Element).visitChildren(rebuild);
    }
  }

  void updateTheme(bool isDark) {
    _themeProvider.toggleTheme(isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aloo Market',
      navigatorKey: _navigatorKey,
      locale: Locale(AppLocalizations.currentLocale),
      theme: _themeProvider.lightTheme,
      darkTheme: _themeProvider.darkTheme,
      themeMode: _themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // One place for system gesture / 3-button bar inset. Top stays false so
      // green app bars can still draw edge-to-edge under the status bar.
      // Rebuilds when locale changes even if a parent short-circuits updates.
      builder: (context, child) {
        return ListenableBuilder(
          listenable: AppLocalizations.instance,
          builder: (context, _) {
            return SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              minimum: EdgeInsets.zero,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/sign_up': (context) => const SignUpScreen(),
        '/otp_login': (context) => const OTPLoginScreen(),
        '/otp_register': (context) =>
            const SignUpScreen(), // Redirected to SignUpScreen design

        '/language': (context) => const LanguageScreen(),
        '/role': (context) => const RoleScreen(),
        '/kishan_home': (context) => const KishanHomeScreen(),
        '/cold_storage_home': (context) => const ColdStorageHomeScreen(),
        //  '/dashboard': (context) => const DashboardScreen(),
        '/kishan_navbar': (context) => const KishanBottomNavBarPage(),
        '/seller_listing': (context) => const MySellerListingScreen(),

        '/cold_storage_navbar': (context) =>
            const ColdStorageBottomNavBarPage(),
        '/manager_navbar': (context) => const ManagerBottomNavBarPage(),
        '/vyapari_navbar': (context) => const VyapariBottomNavBarPage(),
        '/aloo_mitra_navbar': (context) => const AlooMitraBottomNavBarPage(),
        '/aloo_mitra_registration': (context) =>
            const AlooMitraRegistrationScreen(),
        '/aloo_mitra_home': (context) => const AlooMitraHomeScreen(),

        '/create_sell_request': (context) => const CreateSellRequestScreen(),

        '/mandi_price': (context) => const MandiPricesScreen(),
        '/city_mandi_price': (context) => const CityMandiPricesScreen(),
        '/mandi_price_trend': (context) => const MandiPriceTrendScreen(),
        '/hire_rent_coldstorage': (context) =>
            const HireRentColdStorageScreen(),
        '/cold_storage_listing': (context) => const HireRentColdStorageScreen(),
        '/create_availability': (context) => const CreateAvailabilityScreen(),

        '/rent_sorage': (context) => RentStorageScreen(),
        '/storage_detail': (context) => StorageDetailScreen(),
        '/chat_screen': (context) => ChatScreen(),
        '/conversations': (context) => const ConversationsListScreen(),
        '/new_chat': (context) => const NewChatScreen(),
        '/buy_sell': (context) => BuySellScreen(),
        '/crop_analysis': (context) => CropAnalysisScreen(),
        '/ai_analysis': (context) => const AICropAdvisorScreen(),
        '/notification': (context) => NotificationScreen(),
        '/cold-storage-notifications': (context) =>
            const ColdStorageNotificationScreen(),
        '/transport_service': (context) => TransportServiceScreen(),
        '/buy_potatoes': (context) => BuyPotatoesScreen(),
        '/potatoes_detail_screen': (context) => PotatoDetailsScreen(),
        '/trader_requests': (context) => const TraderRequestsScreen(),
        '/my_buy_requests': (context) => const MyBuyRequestsScreen(),
        '/my_token': (context) => const MyTokenScreen(),
        '/advertise_with_us': (context) => const AdvertiseWithUsScreen(),
        '/admin_home': (context) => const AdminHomeScreen(),
        '/kyc_documents': (context) => const KYCDocumentsScreen(),
        '/my_plan': (context) => const MyPlanScreen(),
        '/transaction_history': (context) => const TransactionHistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
        // VyapariBottomNavBarPage
      },
    );
  }
}
