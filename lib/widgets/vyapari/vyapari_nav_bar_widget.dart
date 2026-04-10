import 'package:aloo_sbji_mandi/core/service/buy_request_notification_state.dart';
import 'package:aloo_sbji_mandi/core/service/choupal_notification_state.dart';
import 'package:aloo_sbji_mandi/core/utils/app_localizations.dart';
import 'package:aloo_sbji_mandi/screens/chaupal_chat_screen.dart';
import 'package:aloo_sbji_mandi/screens/profile_screen.dart';
import 'package:aloo_sbji_mandi/screens/vyapari/vyapari_home_screen.dart';
import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';

class VyapariBottomNavBarPage extends StatefulWidget {
  const VyapariBottomNavBarPage({super.key});

  @override
  State<VyapariBottomNavBarPage> createState() =>
      _VyapariBottomNavBarPageState();
}

class _VyapariBottomNavBarPageState extends State<VyapariBottomNavBarPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    ChoupalNotificationState.init();
    BuyRequestNotificationState.init();
    AppLocalizations.instance.addListener(_onAppLocaleChanged);
  }

  @override
  void dispose() {
    AppLocalizations.instance.removeListener(_onAppLocaleChanged);
    super.dispose();
  }

  void _onAppLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<bool> _onWillPop() async {
    // If not on home tab, go back to home tab first
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    final parentContext = context;
    return await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('exit_app')),
            content: Text(tr('exit_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(tr('no')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(
                    parentContext,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: Text(tr('yes')),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            VyapariHomeScreen(),
            ChaupalChatScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 75,
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  index: 0,
                  iconPath: "assets/home_icon.png",
                  label: tr('home'),
                ),

                ValueListenableBuilder<bool>(
                  valueListenable: ChoupalNotificationState.hasNewMessages,
                  builder: (context, hasNew, _) => _navItem(
                    index: 1,
                    iconPath: "assets/chaupal_icon.png",
                    label: tr('chaupal'),
                    showBadge: hasNew,
                  ),
                ),
                _navItem(
                  index: 2,
                  iconPath: "assets/profile_icon.png",
                  label: tr('profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required String iconPath,
    required String label,
    bool showBadge = false,
  }) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          isSelected
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B4D1E), // green bg
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        iconPath,
                        height: 22,
                        color: Colors.white, // selected color
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      iconPath,
                      height: 22,
                      color: AppColors.isDark(context)
                          ? Colors.grey[400]
                          : Colors.black,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
          if (showBadge)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
