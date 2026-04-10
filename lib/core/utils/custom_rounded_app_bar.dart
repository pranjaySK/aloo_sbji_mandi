import 'package:aloo_sbji_mandi/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomRoundedAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final IconData? leadingIcon;
  final List<Widget>? actions;
  final double height;
  final bool isDrawerIcon;
  final bool showBackButton;

  const CustomRoundedAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.leadingIcon = Icons.arrow_back,
    this.actions,
    // Tall enough for SafeArea + 48px touch targets on notched devices (100 was too tight).
    this.height = 118,
    this.isDrawerIcon = false,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen, // primary green
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              /// Leading Icon — hide back arrow when there's nothing to pop
              if (showBackButton &&
                  (isDrawerIcon || onBack != null || Navigator.canPop(context)))
                IconButton(
                  icon: Icon(leadingIcon, color: Colors.white),
                  onPressed:
                      onBack ??
                      () {
                        if (isDrawerIcon) {
                          Scaffold.of(context).openDrawer();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                )
              else
                const SizedBox(width: 48), // keep title alignment consistent
              /// Title
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              /// Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    actions ??
                    const [
                      SizedBox(width: 40), // keeps title centered
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
