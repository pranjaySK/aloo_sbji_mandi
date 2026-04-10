# Aloo Sbji Mandi — Project Context

> **DO NOT re-analyze this project.** All architecture, patterns, and conventions are documented here.

## Quick Facts
- **Framework:** Flutter (Dart), SDK ^3.10.4
- **Version:** 1.1.0+5
- **Backend:** Node.js at `http://15.206.172.102:8888` (API prefix: `/api/v1`)
- **Platform:** Android (primary), iOS, Web, Windows, macOS, Linux
- **State Management:** None (setState + SharedPreferences + singleton services)
- **Firebase:** Configured but DISABLED (no google-services.json). Code commented out in `main.dart`.
- **Entry point:** `lib/main.dart` → `DevLoginScreen` (route `/`)

## API Constants
- `lib/core/constants/api_constant.dart`
- Web dev: `http://localhost:8888`
- Mobile dev: `http://15.206.172.102:8888`
- Original prod: `http://72.62.226.160` (port 80)

## User Roles & Navigation

| Role | Internal Role String | Bottom Nav Route | Home Screen |
|---|---|---|---|
| Kisan (Farmer) | `farmer` | `/kishan_navbar` | `KishanHomeScreen` |
| Vyapari (Trader) | `trader` | `/vyapari_navbar` | `VyapariHomeScreen` |
| Cold Storage Owner | `cold-storage` | `/cold_storage_navbar` | `ColdStorageHomeScreen` |
| Cold Storage Manager | `cold-storage-manager` | `/manager_navbar` | `ManagerHomeScreen` |
| Aloo Mitra | `aloo-mitra` | `/aloo_mitra_navbar` | `AlooMitraHomeScreen` |
| Admin/Master | `admin` / `master` | `/admin_home` | `AdminHomeScreen` |

### Aloo Mitra Service Types
- `potato-seeds`, `fertilizers`, `machinery-rent`, `transportation`, `gunny-bag`, `majdoor`

### Dev Login Phones (password: `password123`)
- Farmer: `9999900001` | Trader: `9999900002` | Cold Storage: `9999900003`
- Admin: `9999900004` | Aloo Mitra: `9999900005` | Manager: `9999900006`
- Master phone: `8112363785`

## Directory Structure

```
lib/
├── main.dart                          # App entry, routes, theme, notification setup
├── firebase_options.dart              # Firebase config (unused until google-services.json added)
├── core/
│   ├── constants/
│   │   ├── api_constant.dart          # Base URL
│   │   ├── state_city_data.dart       # Indian state/city dropdown data
│   │   ├── indian_states_cities.dart  # Full state-city mapping
│   │   └── legal_copy.dart            # Legal text strings
│   ├── service/                       # ALL API & business logic services (37 files)
│   │   ├── auth_service.dart          # OTP login/register, dev-register, role update, session
│   │   ├── api_service.dart           # EMPTY (0 bytes) — not used
│   │   ├── socket_service.dart        # WebSocket: chat, tokens, boli alerts, buy requests
│   │   ├── local_notification_service.dart  # Local push notifications
│   │   ├── fcm_service.dart           # Firebase Cloud Messaging (disabled)
│   │   ├── user_service.dart          # User profile CRUD
│   │   ├── listing_service.dart       # Farmer sell listings
│   │   ├── booking_service.dart       # Cold storage booking
│   │   ├── token_service.dart         # Token queue system
│   │   ├── payment_service.dart       # Razorpay
│   │   ├── dummy_payment_service.dart # Payment fallback
│   │   ├── chat_service.dart          # 1-on-1 messaging
│   │   ├── post_service.dart          # Chaupal community posts
│   │   ├── boli_alert_service.dart    # Boli (auction) alerts
│   │   ├── cold_storage_service.dart  # Cold storage CRUD
│   │   ├── receipt_service.dart       # Receipt management
│   │   ├── receipt_photo_service.dart # Receipt photo capture
│   │   ├── mandi_price_service.dart   # Market prices
│   │   ├── weather_service.dart       # Weather data
│   │   ├── news_service.dart          # Agricultural news
│   │   ├── kyc_service.dart           # KYC documents
│   │   ├── subscription_service.dart  # Paid plans
│   │   ├── transaction_service.dart   # Transaction history
│   │   ├── trader_request_service.dart# Trader buy requests
│   │   ├── deal_service.dart          # Deal management
│   │   ├── feedback_service.dart      # User feedback
│   │   ├── ai_crop_advisor_service.dart # AI crop advice
│   │   ├── farmer_chatbot_service.dart # Chatbot
│   │   ├── vyapari_analytics_service.dart # Trader analytics
│   │   ├── market_intelligence_service.dart # Market intel
│   │   ├── manager_service.dart       # Manager operations
│   │   ├── aloo_mitra_service.dart    # Aloo Mitra profile
│   │   ├── aloo_calculator_service.dart # Calculator
│   │   ├── advertisement_service.dart # Ads management
│   │   ├── admin_management_service.dart # Admin ops
│   │   ├── location_service.dart      # GPS location
│   │   ├── notification_service.dart  # Notifications
│   │   ├── google_geocoding_service.dart # Geocoding
│   │   ├── choupal_notification_state.dart # Chaupal notification state
│   │   └── buy_request_notification_state.dart # Buy request notification state
│   ├── models/
│   │   ├── receipt_model.dart
│   │   ├── dummy_model.dart
│   │   ├── deal_model.dart
│   │   └── chat_models.dart
│   └── utils/
│       ├── app_localizations.dart     # i18n singleton — use tr('key') for translations
│       ├── custom_rounded_app_bar.dart
│       ├── role_shell_scroll_padding.dart
│       ├── toast_helper.dart          # FlutterToast wrapper
│       ├── phone_number_detector.dart
│       ├── ist_datetime.dart          # IST timezone helper
│       └── auth_error_helper.dart
├── screens/                           # All screens (~70 files)
│   ├── role_screen.dart               # Role selection
│   ├── dev_login_screen.dart          # Dev login with quick-login buttons
│   ├── sign_up_screen.dart            # Registration
│   ├── settings_screen.dart
│   ├── profile_screen.dart
│   ├── edit_profile_screen.dart
│   ├── help_support_screen.dart
│   ├── transaction_history_screen.dart
│   ├── directory_screen.dart
│   ├── crop_analysis_screen.dart
│   ├── analysis_screen.dart
│   ├── create_availbility_screen.dart
│   ├── hire_rent_cold_storage_screen.dart
│   ├── rent_storage_screen.dart
│   ├── storage_detail_screen.dart
│   ├── boli_alerts_screen.dart
│   ├── chaupal_chat_screen.dart
│   ├── kishan/                        # Farmer screens
│   │   ├── kishan_home_screen.dart
│   │   ├── buy_sell_screen.dart
│   │   ├── seller_listing_screen.dart
│   │   ├── create_sell_request_screen.dart
│   │   ├── trader_requests_screen.dart
│   │   ├── my_token_screen.dart
│   │   ├── token_confirmed_screen.dart
│   │   ├── select_lane_screen.dart
│   │   ├── my_listing_detail_screen.dart
│   │   ├── my_bookings_screen.dart
│   │   ├── live_token_status_screen.dart
│   │   ├── kishan_ai_advisory_screen.dart
│   │   ├── edit_listing_screen.dart
│   │   ├── book_storage_dialog.dart
│   │   └── aloo_mitra_screen.dart
│   ├── vyapari/                       # Trader screens
│   │   ├── vyapari_home_screen.dart
│   │   ├── buy_potato_screen.dart
│   │   ├── buy_potato_options_screen.dart
│   │   ├── browse_listings_screen.dart
│   │   ├── potato_detail_screen.dart
│   │   ├── create_buy_request_screen.dart
│   │   ├── my_buy_requests_screen.dart
│   │   ├── vyapari_sell_potato_screen.dart
│   │   ├── vyapari_analytics_screen.dart
│   │   ├── vyapari_ai_advisory_screen.dart
│   │   └── transport_service.dart
│   ├── cold_storage/                  # Cold storage screens
│   │   ├── cold_storage_home_screen.dart
│   │   ├── manager_home_screen.dart
│   │   ├── token_system_screen.dart
│   │   ├── token_requests_screen.dart
│   │   ├── token_queue_management_screen.dart
│   │   ├── operator_dashboard_screen.dart
│   │   ├── manage_storage_screen.dart
│   │   ├── manage_boli_alerts_screen.dart
│   │   ├── lane_management_screen.dart
│   │   ├── counter_selection_screen.dart
│   │   ├── counter_detail_dashboard_screen.dart
│   │   ├── cold_storage_notification_screen.dart
│   │   └── cold_storage_ai_advisory_screen.dart
│   ├── chat/                          # Chat screens
│   │   ├── chat_screen.dart
│   │   ├── chat_detail_screen.dart
│   │   ├── conversations_list_screen.dart
│   │   ├── new_chat_screen.dart
│   │   ├── create_post_screen.dart
│   │   └── post_detail_screen.dart
│   ├── receipt/                       # Receipt screens
│   │   ├── my_receipts_screen.dart
│   │   ├── receipt_view_screen.dart
│   │   ├── web_camera_screen.dart
│   │   └── camera_screen_stub.dart
│   └── [other screens...]
├── widgets/                           # Reusable widgets
│   ├── common_widget.dart/            # Shared widgets
│   │   ├── weather_card.dart
│   │   ├── upload_button_widget.dart
│   │   ├── trader_requests_section.dart
│   │   ├── textfield_widget.dart
│   │   ├── service_card_widget.dart
│   │   ├── primary_button.dart
│   │   ├── popular_mandi_widget.dart
│   │   ├── news_section_widget.dart
│   │   ├── label_widget.dart
│   │   ├── header_section_widget.dart
│   │   ├── drop_down_widget.dart
│   │   ├── direcory_section.dart
│   │   ├── custom_drawer_widget.dart
│   │   └── auto_slider_widget.dart
│   ├── kishan/
│   │   ├── kishan_nav_bar_widget.dart   # Farmer bottom nav
│   │   └── seller_card_widgwt.dart
│   ├── vyapari/
│   │   └── vyapari_nav_bar_widget.dart  # Trader bottom nav
│   ├── cold_storage/
│   │   ├── cold_storage_nav_bar_widget.dart  # Owner bottom nav
│   │   └── manager_nav_bar_widget.dart     # Manager bottom nav
│   ├── aloo_mitra/
│   │   └── aloo_mitra_nav_bar_widget.dart  # Aloo Mitra bottom nav
│   ├── language_toggle_widget.dart
│   ├── notification_bell_widget.dart
│   ├── cold_storage_notification_bell.dart
│   ├── location_map_widget.dart
│   ├── listing_filter_sheet.dart
│   └── boli_alert_banner.dart
└── theme/
    ├── app_colors.dart                # Color constants + dark-mode helpers
    └── theme_provider.dart            # ThemeNotifier singleton
```

## All Routes (main.dart)

```
/                    → DevLoginScreen
/login               → LoginScreen
/sign_up             → SignUpScreen
/otp_login           → OTPLoginScreen
/otp_register        → SignUpScreen
/language            → LanguageScreen
/role                → RoleScreen
/kishan_home         → KishanHomeScreen
/cold_storage_home   → ColdStorageHomeScreen
/kishan_navbar       → KishanBottomNavBarPage
/seller_listing      → MySellerListingScreen
/cold_storage_navbar → ColdStorageBottomNavBarPage
/manager_navbar      → ManagerBottomNavBarPage
/vyapari_navbar      → VyapariBottomNavBarPage
/aloo_mitra_navbar   → AlooMitraBottomNavBarPage
/aloo_mitra_registration → AlooMitraRegistrationScreen
/aloo_mitra_home     → AlooMitraHomeScreen
/create_sell_request → CreateSellRequestScreen
/mandi_price         → MandiPricesScreen
/city_mandi_price    → CityMandiPricesScreen
/mandi_price_trend   → MandiPriceTrendScreen
/hire_rent_coldstorage → HireRentColdStorageScreen
/cold_storage_listing → HireRentColdStorageScreen
/create_availability → CreateAvailabilityScreen
/rent_sorage         → RentStorageScreen
/storage_detail      → StorageDetailScreen
/chat_screen         → ChatScreen
/conversations       → ConversationsListScreen
/new_chat            → NewChatScreen
/buy_sell            → BuySellScreen
/crop_analysis       → CropAnalysisScreen
/ai_analysis         → AICropAdvisorScreen
/notification        → NotificationScreen
/cold-storage-notifications → ColdStorageNotificationScreen
/transport_service   → TransportServiceScreen
/buy_potatoes        → BuyPotatoesScreen
/potatoes_detail_screen → PotatoDetailsScreen
/trader_requests     → TraderRequestsScreen
/my_buy_requests     → MyBuyRequestsScreen
/my_token            → MyTokenScreen
/advertise_with_us   → AdvertiseWithUsScreen
/admin_home          → AdminHomeScreen
/kyc_documents       → KYCDocumentsScreen
/my_plan             → MyPlanScreen
/transaction_history → TransactionHistoryScreen
/settings            → SettingsScreen
```

## Socket Events (socket_service.dart)

### Chat
- `receiveMessage` — incoming message
- `messageSent` — send confirmation
- `messageDelivered` — delivery receipt
- `messagesRead` — read receipt
- `userOnline` / `userOffline` / `onlineStatuses`
- `userTyping`
- `joinedConversation`
- Emit: `joinConversation`, `leaveConversation`, `sendMessage`, `markAsRead`, `typing`, `getOnlineStatus`

### Token Queue
- `token_called` — farmer's turn now
- `token_nearby` — turn is coming
- `token_issued` — token confirmed
- `token_in_service` — service started
- `token_completed` — service done
- `token_skipped` — token skipped
- `token_transferred` — counter changed
- `token_rejected` — token rejected
- `token_queue_update` — position update
- `token_queue_updated` — queue updated (owner)

### Other
- `boli_alert_reminder` — auction alert (3/2/1 days before)
- `buy_request_response` — farmer responded to trader buy request

## Auth Flow

1. **OTP Login:** `sendLoginOTP(phone)` → `verifyLoginOTP(phone, otp)` → saves to SharedPreferences
2. **OTP Register:** `registerAndSendOTP(...)` → `verifyOTPAndRegister(phone, otp)`
3. **Dev Login:** `login(phone, password)` or `register(...)` via `/api/v1/user/dev-register`
4. **Session stored in:** `accessToken`, `refreshToken`, `user`, `userRole`, `userId`, `isMaster`
5. **Logout:** clears all SharedPreferences keys

## API Patterns

All services follow this pattern:
```dart
class SomeService {
  static const String baseUrl = '${ApiConstants.baseUrl}/api/v1';

  Future<Map<String, dynamic>> someMethod() async {
    try {
      final token = await AuthService().getAccessToken();
      final response = await http.post/get/put/delete(
        Uri.parse('$baseUrl/some-endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({...}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
```

## Theme & Colors

- `AppColors.primaryGreen` = `Color(0xFF004711)` — main brand color
- `AppColors.lightGreen` = `Color(0xFFCFFF9E)`
- `AppColors.cardBg(context)` — dark-mode aware card background
- `AppColors.textPrimary(context)` / `textSecondary(context)` / `textHint(context)`
- `ThemeProvider` — singleton via `ThemeNotifier.instance`
- Font: Google Fonts `Noto Sans` (supports Hindi)

## i18n

- `import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';`
- Use `tr('key')` for translated strings
- Locale stored in `AppLocalizations.currentLocale`
- Supports English + Hindi

## Conventions

1. **No comments** unless explicitly asked
2. **No emojis** in code unless explicitly asked
3. **Use `AppColors`** helpers, not hardcoded colors
4. **Use `tr()`** for all user-facing strings
5. **Services return** `{'success': bool, 'data': ..., 'message': ...}`
6. **Screens use** `setState` for local state
7. **Navigation** via `Navigator.pushNamed(context, '/route')`
8. **Bottom nav bars** use `IndexedStack` to preserve state
9. **api_service.dart is EMPTY** — services make direct http calls
10. **Dev login** screen has one-tap buttons for each role

## Dependencies

```
google_fonts, dotted_border, fl_chart, http, shared_preferences, intl,
url_launcher, share_plus, socket_io_client, image_picker, razorpay_flutter,
uuid, path_provider, image_cropper, geolocator, geocoding, fluttertoast,
flutter_local_notifications, firebase_core, firebase_messaging
```

## How to Add Things

### New Screen
1. Create file in `lib/screens/[role]/name_screen.dart`
2. Add route in `main.dart` routes map
3. If needs bottom nav, add to appropriate `*_nav_bar_widget.dart` IndexedStack

### New API Service
1. Create file in `lib/core/service/name_service.dart`
2. Follow the API pattern above (return `{'success', 'data', 'message'}`)
3. Import and instantiate in screens

### New Widget
1. Common widgets → `lib/widgets/common_widget.dart/name_widget.dart`
2. Role-specific → `lib/widgets/[role]/name_widget.dart`

### New Route
Add to `routes: {}` map in `main.dart`

## Known Issues
- `api_service.dart` is empty (0 bytes) — not used anywhere
- Firebase disabled (no google-services.json)
- No global error handling / error boundaries
- No formal state management
- Hardcoded dev credentials in `dev_login_screen.dart`
- `api_service.dart` exists but is empty — all services make direct http calls

## API Endpoints

| Endpoint | Method | File | Function | Description |
|---|---|---|---|---|
| **AUTH** |||||
| `/api/v1/user/register` | POST | auth_service.dart | `registerAndSendOTP` | Register user & send OTP |
| `/api/v1/user/verify-otp` | POST | auth_service.dart | `verifyOTPAndRegister` | Verify OTP & complete registration |
| `/api/v1/user/resend-otp` | POST | auth_service.dart | `resendOTP` | Resend OTP |
| `/api/v1/user/dev-find-manager` | GET | auth_service.dart | `devFindManager` | Find existing cold storage manager (dev) |
| `/api/v1/user/login/send-otp` | POST | auth_service.dart | `sendLoginOTP` | Send login OTP |
| `/api/v1/user/login/verify-otp` | POST | auth_service.dart | `verifyLoginOTP` | Verify login OTP |
| `/api/v1/user/login` | POST | auth_service.dart | `login` | Password-based login (legacy) |
| `/api/v1/user/dev-register` | POST | auth_service.dart | `register` | Dev registration (testing) |
| `/api/v1/user/profile/update` | PUT | auth_service.dart | `updateUserRole` | Update user role |
| `/api/v1/aloo-mitra/profile` | PUT | auth_service.dart | `updateAlooMitraProfile` | Update Aloo Mitra profile |
| **USER** |||||
| `/api/v1/user/me` | GET | user_service.dart | `getCurrentUser` | Get current user profile |
| `/api/v1/user/profile/update` | PUT | user_service.dart | `updateProfile` | Update user profile |
| `/api/v1/user/aloo-mitras` | GET | screens/kishan/aloo_mitra_screen.dart | `_loadAlooMitras` | Get Aloo Mitras list |
| **LISTINGS** |||||
| `/api/v1/listings` | GET | listing_service.dart | `getAllListings` | Get all listings with filters |
| `/api/v1/listings/sell` | GET | listing_service.dart | `getSellListings` | Get sell listings with filters |
| `/api/v1/listings/buy` | GET | listing_service.dart | `getBuyListings` | Get buy listings with filters |
| `/api/v1/listings/user/my` | GET | listing_service.dart | `getMyListings` | Get current user's listings |
| `/api/v1/listings/create` | POST | listing_service.dart | `createListing` | Create a new listing |
| `/api/v1/listings/:id` | PUT | listing_service.dart | `updateListing` | Update a listing |
| `/api/v1/listings/:id` | DELETE | listing_service.dart | `deleteListing` | Delete a listing |
| `/api/v1/listings/:id/toggle` | PATCH | listing_service.dart | `toggleListingStatus` | Toggle listing active status |
| **BOOKINGS** |||||
| `/api/v1/bookings/create` | POST | booking_service.dart | `createBooking` | Create a new booking |
| `/api/v1/bookings/my-bookings` | GET | booking_service.dart | `getMyBookings` | Get farmer's bookings |
| `/api/v1/bookings/requests` | GET | booking_service.dart | `getBookingRequests` | Get booking requests (owner) |
| `/api/v1/bookings/:id` | GET | booking_service.dart | `getBooking` | Get single booking |
| `/api/v1/bookings/:id` | PATCH | booking_service.dart | `updateBooking` | Update booking (farmer) |
| `/api/v1/bookings/:id/respond` | PATCH | booking_service.dart | `respondToBooking` | Accept/reject booking (owner) |
| `/api/v1/bookings/:id/cancel` | PATCH | booking_service.dart | `cancelBooking` | Cancel booking (farmer) |
| `/api/v1/bookings/:id` | DELETE | booking_service.dart | `deleteBooking` | Delete booking (owner) |
| **COLD STORAGE** |||||
| `/api/v1/cold-storage` | GET | cold_storage_service.dart | `getAllColdStorages` | Get all cold storages with filters |
| `/api/v1/cold-storage/:id` | GET | cold_storage_service.dart | `getColdStorageById` | Get cold storage by ID |
| `/api/v1/cold-storage/my` | GET | cold_storage_service.dart | `getMyColdStorages` | Get owner's cold storages |
| `/api/v1/cold-storage/create` | POST | cold_storage_service.dart | `createColdStorage` | Create cold storage |
| `/api/v1/cold-storage/:id` | PUT | cold_storage_service.dart | `updateColdStorage` | Update cold storage |
| `/api/v1/cold-storage/:id/toggle` | PATCH | cold_storage_service.dart | `toggleAvailability` | Toggle availability |
| `/api/v1/cold-storage/:id` | DELETE | cold_storage_service.dart | `deleteColdStorage` | Delete cold storage |
| `/api/v1/cold-storage/:id/rating` | POST | cold_storage_service.dart | `addRating` | Add rating to cold storage |
| `/api/v1/cold-storage/:id/ratings` | GET | cold_storage_service.dart | `getRatings` | Get ratings for cold storage |
| `/api/v1/cold-storage/:id/assign-manager` | POST | cold_storage_service.dart | `assignManager` | Assign manager to cold storage |
| `/api/v1/cold-storage/:id/remove-manager` | DELETE | cold_storage_service.dart | `removeManager` | Remove manager from cold storage |
| `/api/v1/cold-storage/manager/my-storage` | GET | cold_storage_service.dart | `getManagerColdStorage` | Get manager's assigned cold storage |
| **TOKENS** |||||
| `/api/v1/tokens/request` | POST | token_service.dart | `requestToken` | Request a token for cold storage |
| `/api/v1/tokens/my-tokens` | GET | token_service.dart | `getMyTokens` | Get user's tokens for today |
| `/api/v1/tokens/status/:id` | GET | token_service.dart | `getTokenStatus` | Get specific token status |
| `/api/v1/tokens/cancel/:id` | PATCH | token_service.dart | `cancelMyToken` | Cancel a token |
| `/api/v1/tokens/update/:id` | PATCH | token_service.dart | `updateMyToken` | Update pending token request |
| `/api/v1/tokens/delete/:id` | PATCH | token_service.dart | `deleteMyToken` | Delete pending token request |
| `/api/v1/tokens/queue-info/:coldStorageId` | GET | token_service.dart | `getQueueInfo` | Get public queue info (no auth) |
| `/api/v1/tokens/issue/:coldStorageId` | POST | token_service.dart | `issueToken` | Issue token to farmer (owner) |
| `/api/v1/tokens/queue/:coldStorageId` | GET | token_service.dart | `getTokenQueue` | Get token queue for cold storage |
| `/api/v1/tokens/call-next/:coldStorageId` | POST | token_service.dart | `callNextToken` | Call next token (per-counter) |
| `/api/v1/tokens/start-service/:id` | PATCH | token_service.dart | `startServing` | Start serving a token |
| `/api/v1/tokens/complete/:id` | PATCH | token_service.dart | `completeToken` | Complete a token |
| `/api/v1/tokens/skip/:id` | PATCH | token_service.dart | `skipToken` | Skip a token |
| `/api/v1/tokens/requeue/:id` | PATCH | token_service.dart | `requeueToken` | Re-queue a skipped token |
| `/api/v1/tokens/approve/:id` | PATCH | token_service.dart | `approveTokenRequest` | Approve pending token (owner) |
| `/api/v1/tokens/reject/:id` | PATCH | token_service.dart | `rejectTokenRequest` | Reject pending token (owner) |
| `/api/v1/tokens/transfer/:id` | PATCH | token_service.dart | `transferToken` | Transfer token to different counter |
| `/api/v1/counters/:coldStorageId` | GET | token_service.dart | `getCounters` | Get all counters for cold storage |
| `/api/v1/counters/:coldStorageId` | POST | token_service.dart | `createCounter` | Create a new counter |
| `/api/v1/counters/update/:id` | PUT | token_service.dart | `updateCounter` | Update a counter |
| `/api/v1/counters/delete/:id` | DELETE | token_service.dart | `deleteCounter` | Delete a counter |
| `/api/v1/counters/:coldStorageId/setup-default` | POST | token_service.dart | `setupDefaultCounters` | Setup default counters |
| **PAYMENTS** |||||
| `/api/v1/payments/create-order` | POST | payment_service.dart | `createPaymentOrder` | Create Razorpay payment order |
| `/api/v1/payments/verify` | POST | payment_service.dart | `verifyPayment` | Verify Razorpay payment |
| `/api/v1/payments/status/:dealId` | GET | payment_service.dart | `getPaymentStatus` | Get payment status for deal |
| `/api/v1/payments/key` | GET | payment_service.dart | `getRazorpayKey` | Get Razorpay key |
| **CHAT** |||||
| `/api/v1/chat/conversations` | GET | chat_service.dart | `getConversations` | Get all conversations |
| `/api/v1/chat/users` | GET | chat_service.dart | `getChatableUsers` | Get users available to chat |
| `/api/v1/chat/users/search` | GET | chat_service.dart | `searchUsers` | Search users by query/role |
| `/api/v1/chat/conversation/:userId` | GET | chat_service.dart | `getOrCreateConversation` | Get or create conversation |
| `/api/v1/chat/messages/:conversationId` | GET | chat_service.dart | `getMessages` | Get messages for conversation |
| `/api/v1/chat/messages/:conversationId` | POST | chat_service.dart | `sendMessage` | Send message (REST fallback) |
| `/api/v1/chat/messages/:conversationId/read` | PATCH | chat_service.dart | `markAsRead` | Mark messages as read |
| `/api/v1/chat/users/online` | GET | chat_service.dart | `getOnlineStatus` | Get online status for users |
| **POSTS (Chaupal)** |||||
| `/api/v1/posts` | GET | post_service.dart | `getAllPosts` | Get all posts with filters |
| `/api/v1/posts/create` | POST | post_service.dart | `createPost` | Create a new post |
| `/api/v1/posts/:id` | PATCH/POST/PUT | post_service.dart | `updatePost` | Update a post |
| `/api/v1/posts/:id` | DELETE | post_service.dart | `deletePost` | Delete a post |
| `/api/v1/posts/:id` | GET | post_service.dart | `getPost` | Get single post |
| `/api/v1/posts/:id/like` | PATCH | post_service.dart | `toggleLike` | Like/unlike a post |
| `/api/v1/posts/:id/comment` | POST | post_service.dart | `addComment` | Add comment to post |
| `/api/v1/posts/:id/comment/:commentId/reply` | POST | post_service.dart | `replyToComment` | Reply to a comment |
| `/api/v1/posts/:id/comment/:commentId/like` | PATCH | post_service.dart | `toggleCommentLike` | Like/unlike a comment |
| `/api/v1/posts/:id/share` | PATCH | post_service.dart | `trackShare` | Track post share |
| **BOLI ALERTS** |||||
| `/api/v1/boli-alerts` | GET | boli_alert_service.dart | `getAllBoliAlerts` | Get all active boli alerts |
| `/api/v1/boli-alerts/cold-storage/:id` | GET | boli_alert_service.dart | `getBoliAlertsByColdStorage` | Get boli alerts for cold storage |
| `/api/v1/boli-alerts/my` | GET | boli_alert_service.dart | `getMyBoliAlerts` | Get owner's boli alerts |
| `/api/v1/boli-alerts/create` | POST | boli_alert_service.dart | `createBoliAlert` | Create boli alert |
| `/api/v1/boli-alerts/:id` | PUT | boli_alert_service.dart | `updateBoliAlert` | Update boli alert |
| `/api/v1/boli-alerts/:id` | DELETE | boli_alert_service.dart | `deleteBoliAlert` | Delete boli alert |
| **RECEIPTS** |||||
| `/api/v1/receipts/generate` | POST | receipt_service.dart | `generateReceipt` | Generate receipt for a deal |
| `/api/v1/receipts/deal/:dealId` | GET | receipt_service.dart | `getReceiptByDealId` | Get receipt by deal ID |
| `/api/v1/receipts/number/:receiptNumber` | GET | receipt_service.dart | `getReceiptByNumber` | Get receipt by receipt number |
| `/api/v1/receipts/my-receipts` | GET | receipt_service.dart | `getMyReceipts` | Get user's receipts |
| `/api/v1/receipts/downloaded/:id` | PATCH | receipt_service.dart | `markAsDownloaded` | Mark receipt as downloaded |
| **KYC** |||||
| `/api/v1/kyc/status` | GET | kyc_service.dart | `getKycStatus` | Get KYC status |
| `/api/v1/kyc/send-otp` | POST | kyc_service.dart | `sendAadhaarOtp` | Send Aadhaar OTP |
| `/api/v1/kyc/verify-otp` | POST | kyc_service.dart | `verifyAadhaarOtp` | Verify Aadhaar OTP |
| `/api/v1/kyc/resend-otp` | POST | kyc_service.dart | `resendAadhaarOtp` | Resend Aadhaar OTP |
| `/api/v1/kyc/upload-photo` | POST | kyc_service.dart | `uploadAadhaarPhoto` | Upload Aadhaar photo |
| **TRANSACTIONS** |||||
| `/api/v1/transactions` | GET | transaction_service.dart | `getTransactionHistory` | Get transaction history |
| `/api/v1/transactions/:id` | GET | transaction_service.dart | `getTransactionById` | Get transaction by ID |
| `/api/v1/transactions` | POST | transaction_service.dart | `createTransaction` | Create a new transaction |
| `/api/v1/transactions/stats` | GET | transaction_service.dart | `getTransactionStats` | Get transaction statistics |
| **TRADER REQUESTS** |||||
| `/api/v1/trader-requests` | GET | trader_request_service.dart | `getAllRequests` | Get all open trader requests |
| `/api/v1/trader-requests/:id` | GET | trader_request_service.dart | `getRequestById` | Get single request |
| `/api/v1/trader-requests/user/my` | GET | trader_request_service.dart | `getMyRequests` | Get trader's own requests |
| `/api/v1/trader-requests/create` | POST | trader_request_service.dart | `createRequest` | Create trader buy request |
| `/api/v1/trader-requests/:id/respond` | POST | trader_request_service.dart | `respondToRequest` | Farmer responds to request |
| `/api/v1/trader-requests/:id/response/:responseId` | PATCH | trader_request_service.dart | `updateResponseStatus` | Accept/reject farmer response |
| `/api/v1/trader-requests/:id` | PATCH | trader_request_service.dart | `updateRequest` | Update trader request |
| `/api/v1/trader-requests/:id` | DELETE | trader_request_service.dart | `cancelRequest` | Cancel/delete trader request |
| `/api/v1/trader-requests/farmer/my-responses` | GET | trader_request_service.dart | `getMyResponses` | Get farmer's responses (My Offers) |
| `/api/v1/trader-requests/:id/my-response` | DELETE | trader_request_service.dart | `withdrawMyResponse` | Withdraw farmer's response |
| **DEALS** |||||
| `/api/v1/deals/propose` | POST | deal_service.dart | `proposeDeal` | Propose a new deal |
| `/api/v1/deals/:id/confirm` | PATCH | deal_service.dart | `confirmDeal` | Confirm a deal |
| `/api/v1/deals/:id/cancel` | PATCH | deal_service.dart | `cancelDeal` | Cancel a deal |
| `/api/v1/deals/conversation/:conversationId` | GET | deal_service.dart | `getDealsForConversation` | Get deals for conversation |
| `/api/v1/deals/my-deals` | GET | deal_service.dart | `getMyDeals` | Get user's deals |
| `/api/v1/deals/:id` | GET | deal_service.dart | `getDeal` | Get single deal |
| `/api/v1/deals/:id/confirm-payment-sent` | PATCH | deal_service.dart | `confirmPaymentSent` | Confirm payment sent |
| `/api/v1/deals/:id/confirm-payment-received` | PATCH | deal_service.dart | `confirmPaymentReceived` | Confirm payment received |
| **ALOO MITRA** |||||
| `/api/v1/aloo-mitra/profile` | GET | aloo_mitra_service.dart | `getAlooMitraProfile` | Get Aloo Mitra profile |
| `/api/v1/aloo-mitra/profile` | PUT | aloo_mitra_service.dart | `updateAlooMitraProfile` | Update Aloo Mitra profile |
| `/api/v1/aloo-mitra/stats` | GET | aloo_mitra_service.dart | `getAlooMitraStats` | Get Aloo Mitra statistics |
| `/api/v1/aloo-mitra/providers` | GET | aloo_mitra_service.dart | `getServiceProviders` | Get service providers list |
| `/api/v1/aloo-mitra/enquiry` | POST | aloo_mitra_service.dart | `sendEnquiry` | Send enquiry to provider |
| `/api/v1/aloo-mitra/enquiries` | GET | aloo_mitra_service.dart | `getReceivedEnquiries` | Get received enquiries |
| **ADVERTISEMENTS** |||||
| `/api/v1/advertisements/pricing` | GET | advertisement_service.dart | `getAdPricing` | Get ad slide pricing (public) |
| `/api/v1/advertisements/admin/pricing` | PUT | advertisement_service.dart | `updateAdPricing` | Update ad pricing (admin) |
| `/api/v1/advertisements/active` | GET | advertisement_service.dart | `getActiveAdvertisements` | Get active ads for slider (public) |
| `/api/v1/advertisements/request` | POST | advertisement_service.dart | `createAdvertisementRequest` | Create ad request |
| `/api/v1/advertisements/my` | GET | advertisement_service.dart | `getMyAdvertisements` | Get user's advertisements |
| `/api/v1/advertisements/:id/view` | POST | advertisement_service.dart | `trackAdView` | Track ad view |
| `/api/v1/advertisements/:id/click` | POST | advertisement_service.dart | `trackAdClick` | Track ad click |
| `/api/v1/advertisements/pay/create-order` | POST | advertisement_service.dart | `createAdPaymentOrder` | Create Razorpay order for ad |
| `/api/v1/advertisements/pay/verify` | POST | advertisement_service.dart | `verifyAdPayment` | Verify Razorpay payment for ad |
| `/api/v1/advertisements/admin/all` | GET | advertisement_service.dart | `getAllAdvertisements` | Get all ads (admin) |
| `/api/v1/advertisements/admin/pending` | GET | advertisement_service.dart | `getPendingAdvertisements` | Get pending ads (admin) |
| `/api/v1/advertisements/admin/:id/approve` | PATCH | advertisement_service.dart | `approveAdvertisement` | Approve ad (admin) |
| `/api/v1/advertisements/admin/:id/reject` | PATCH | advertisement_service.dart | `rejectAdvertisement` | Reject ad (admin) |
| **ADMIN** |||||
| `/api/v1/admin/check-role` | GET | admin_management_service.dart | `checkRole` | Check if user is master |
| `/api/v1/admin/admins` | GET | admin_management_service.dart | `getAllAdmins` | Get all admins (master) |
| `/api/v1/admin/create-admin` | POST | admin_management_service.dart | `createAdmin` | Create new admin (master) |
| `/api/v1/admin/update-admin/:id` | PUT | admin_management_service.dart | `updateAdmin` | Update admin (master) |
| `/api/v1/admin/delete-admin/:id` | DELETE | admin_management_service.dart | `deleteAdmin` | Delete admin (master) |
| `/api/v1/admin/demote-admin/:id` | PUT | admin_management_service.dart | `demoteAdmin` | Demote admin to user (master) |
| `/api/v1/admin/broadcast-notification` | POST | admin_management_service.dart | `sendBroadcastNotification` | Send broadcast notification |
| **NOTIFICATIONS** |||||
| `/api/v1/notifications` | GET | notification_service.dart | `getNotifications` | Get all notifications |
| `/api/v1/notifications/unread-count` | GET | notification_service.dart | `getUnreadCount` | Get unread notification count |
| `/api/v1/notifications/:id/read` | PATCH | notification_service.dart | `markAsRead` | Mark notification as read |
| `/api/v1/notifications/read-all` | PATCH | notification_service.dart | `markAllAsRead` | Mark all notifications as read |
| `/api/v1/notifications/seen-all` | PATCH | notification_service.dart | `markAllAsSeen` | Mark all notifications as seen |
| `/api/v1/notifications/:id` | DELETE | notification_service.dart | `deleteNotification` | Delete notification |
| `/api/v1/notifications` | DELETE | notification_service.dart | `clearAll` | Clear all notifications |
| **MANAGER** |||||
| `/api/v1/manager/dashboard` | GET | manager_service.dart | `getDashboard` | Get manager dashboard |
| `/api/v1/manager/my-storage` | GET | manager_service.dart | `getMyStorage` | Get manager's assigned storage |
| `/api/v1/manager/my-storage` | PUT | manager_service.dart | `updateStorageDetails` | Update storage details |
| `/api/v1/manager/my-storage/toggle` | PATCH | manager_service.dart | `toggleAvailability` | Toggle storage availability |
| `/api/v1/manager/bookings` | GET | manager_service.dart | `getBookingRequests` | Get booking requests |
| `/api/v1/manager/bookings/stats` | GET | manager_service.dart | `getBookingStats` | Get booking statistics |
| `/api/v1/manager/bookings/:id/respond` | PATCH | manager_service.dart | `respondToBooking` | Respond to booking (accept/reject) |
| `/api/v1/manager/profile` | GET | manager_service.dart | `getProfile` | Get manager profile |
| `/api/v1/manager/profile` | PUT | manager_service.dart | `updateProfile` | Update manager profile |
| **SUBSCRIPTIONS** |||||
| `/api/v1/subscriptions/plans` | GET | subscription_service.dart | `getPlans` | Get all subscription plans |
| `/api/v1/subscriptions/current` | GET | subscription_service.dart | `getCurrentSubscription` | Get current user's subscription |
| `/api/v1/subscriptions/create-order` | POST | subscription_service.dart | `createSubscriptionOrder` | Create Razorpay order for subscription |
| `/api/v1/subscriptions/verify` | POST | subscription_service.dart | `verifyPayment` | Verify subscription payment |
| `/api/v1/subscriptions/history` | GET | subscription_service.dart | `getSubscriptionHistory` | Get subscription history |
| `/api/v1/subscriptions/cancel/:id` | POST | subscription_service.dart | `cancelSubscription` | Cancel subscription |
| **ANALYTICS** |||||
| `/api/v1/analytics/vyapari-insights` | GET | vyapari_analytics_service.dart | `getVyapariInsights` | Get trader AI insights |
| **FEEDBACK** |||||
| `/api/v1/api/feedback` | POST | feedback_service.dart | `submitFeedback` | Submit feedback |
| `/api/v1/api/feedback` | GET | feedback_service.dart | `getAllFeedbacks` | Get all feedbacks (admin) |
| `/api/v1/api/feedback/:id` | PUT | feedback_service.dart | `updateFeedbackStatus` | Update feedback status (admin) |
| `/api/v1/api/feedback/:id` | DELETE | feedback_service.dart | `deleteFeedback` | Delete feedback (admin) |
| **EXTERNAL APIs** |||||
| `https://api.postalpincode.in/pincode/:pincode` | GET | sign_up_screen.dart | `_fetchLocationFromPincode` | Fetch location from pincode (India Post) |
| `https://api.postalpincode.in/pincode/:pincode` | GET | cold_storage/manage_storage_screen.dart | `_fetchLocationFromPincode` | Fetch location from pincode (India Post) |
| `https://api.data.gov.in/resource/35985678...` | GET | mandi_price_service.dart | `fetchMandiPrices` | Fetch potato mandi prices (data.gov.in) |
| `https://api.openweathermap.org/data/2.5/weather` | GET | weather_service.dart | `getWeatherByCity` | Get weather by city (OpenWeatherMap) |
| `https://api.openweathermap.org/data/2.5/weather` | GET | weather_service.dart | `getWeatherByLocation` | Get weather by coordinates |
| `http://ip-api.com/json/` | GET | weather_service.dart | `_getLocationFromIP` | Get location from IP |
| `https://newsapi.org/v2/everything` | GET | news_service.dart | `_fetchFromNewsApi` | Fetch agriculture news (NewsAPI) |
| `https://api.data.gov.in/resource/9ef84268...` | GET | market_intelligence_service.dart | `fetchPotatoPrices` | Fetch live potato prices (data.gov.in) |
