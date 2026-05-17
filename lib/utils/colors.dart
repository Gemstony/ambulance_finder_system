import 'package:flutter/material.dart';

class AppColors {
  // Primary theme colors (Hospital style)
  static const Color primaryGreen = Color(0xFF4CAF50);      // Light green
  static const Color lightGreen = Color(0xFF81C784);        // Soft light green
  static const Color veryLightGreen = Color(0xFFC8E6C9);     // Very light green background
  
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightRed = Color(0xFFEF9A9A);          // Soft red for emergency
  static const Color darkRed = Color(0xFFE53935);           // Darker red for buttons
  
  // Secondary colors
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF616161);
  static const Color black = Color(0xFF212121);
  static const Color lightGrey = Color(0xFFF5F5F5);
  
  // Status colors
  static const Color pending = Color(0xFFFFA726);    // Orange
  static const Color accepted = Color(0xFF42A5F5);  // Blue
  static const Color enroute = Color(0xFF26C6DA);   // Cyan
  static const Color arrived = Color(0xFF66BB6A);   // Green
  static const Color completed = Color(0xFF9E9E9E); // Grey
  
  // Gradients
  static LinearGradient primaryGradient = const LinearGradient(
    colors: [primaryGreen, lightGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient emergencyGradient = const LinearGradient(
    colors: [darkRed, lightRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}