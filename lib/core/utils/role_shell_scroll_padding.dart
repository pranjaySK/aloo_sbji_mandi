import 'package:flutter/material.dart';

/// Scroll / list padding for screens shown inside role bottom-nav shells.
/// Compensates for nested [Scaffold] + floating pill bar. System nav inset is
/// handled globally by [MaterialApp.builder] → [SafeArea] in `main.dart`.
class RoleShellScrollPadding {
  RoleShellScrollPadding._();

  static const double _barClearance = 28;

  static EdgeInsets _bottomHeavy({
    required double horizontal,
    required double top,
    required double baseBottom,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      baseBottom + _barClearance,
    );
  }

  /// Farmer / trader / cold-storage / aloo-mitra home (12px sides).
  static EdgeInsets get home =>
      _bottomHeavy(horizontal: 12, top: 12, baseBottom: 12);

  /// Manager dashboard scroll (16px sides).
  static EdgeInsets get managerHome =>
      _bottomHeavy(horizontal: 16, top: 16, baseBottom: 16);

  /// Profile tab (20px sides).
  static EdgeInsets get profile =>
      _bottomHeavy(horizontal: 20, top: 20, baseBottom: 20);

  /// Chaupal lists (posts / chats).
  static EdgeInsets get chaupalList =>
      _bottomHeavy(horizontal: 12, top: 12, baseBottom: 12);
}
