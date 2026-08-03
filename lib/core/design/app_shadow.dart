import 'package:flutter/material.dart';

abstract final class AppShadow {
  const AppShadow._();

  /// Standard cards
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Elevated cards / dialogs
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x22000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// Floating elements
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];
}