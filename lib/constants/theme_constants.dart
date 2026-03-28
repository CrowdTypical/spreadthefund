// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'package:flutter/material.dart';

// ── App-wide color palette ──

class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0E14);
  static const surface = Color(0xFF141A22);
  static const border = Color(0xFF1E2A35);
  static const accent = Color(0xFF00E5CC);
  static const danger = Color(0xFFFF4C5E);
  static const textPrimary = Color(0xFFE0E0E0);
  static const textMuted = Color(0xFF8899AA);
  static const textDim = Color(0xFF556677);
}

// ── App-wide text styles ──

class AppTextStyles {
  AppTextStyles._();

  static const mono = TextStyle(fontFamily: 'monospace');
}

// ── Category constants ──

class Category {
  final String name;
  final IconData icon;
  const Category(this.name, this.icon);
}

const List<Category> defaultCategories = [
  Category('Food', Icons.restaurant),
  Category('Transport', Icons.directions_car),
  Category('Groceries', Icons.shopping_cart),
  Category('Entertainment', Icons.movie),
  Category('Utilities', Icons.bolt),
  Category('Rent', Icons.home),
  Category('Shopping', Icons.shopping_bag),
  Category('Health', Icons.medical_services),
];

const categoryIcons = <String, IconData>{
  'food': Icons.restaurant,
  'transport': Icons.directions_car,
  'groceries': Icons.shopping_cart,
  'entertainment': Icons.movie,
  'utilities': Icons.bolt,
  'rent': Icons.home,
  'shopping': Icons.shopping_bag,
  'health': Icons.medical_services,
};

const categoryColors = <String, Color>{
  'food': Color(0xFFFFA726),
  'transport': Color(0xFF42A5F5),
  'groceries': Color(0xFF66BB6A),
  'entertainment': Color(0xFFAB47BC),
  'utilities': Color(0xFFFFEE58),
  'rent': Color(0xFFEF5350),
  'shopping': Color(0xFFEC407A),
  'health': Color(0xFF26C6DA),
};

IconData iconForCategory(String name) {
  return categoryIcons[name.toLowerCase()] ?? Icons.receipt_long;
}

Color colorForCategory(String name) {
  return categoryColors[name.toLowerCase()] ?? AppColors.textMuted;
}

// ── Group icon palette ──

const groupIcons = <String, IconData>{
  'group': Icons.group,
  'person': Icons.person,
  'home': Icons.home,
  'favorite': Icons.favorite,
  'star': Icons.star,
  'rocket': Icons.rocket_launch,
  'pet': Icons.pets,
  'music': Icons.music_note,
  'game': Icons.sports_esports,
  'travel': Icons.flight,
  'food': Icons.restaurant,
  'coffee': Icons.coffee,
  'fitness': Icons.fitness_center,
  'school': Icons.school,
  'work': Icons.work,
  'beach': Icons.beach_access,
  'fire': Icons.local_fire_department,
  'diamond': Icons.diamond,
  'bolt': Icons.bolt,
  'palette': Icons.palette,
  'camera': Icons.camera_alt,
  'cake': Icons.cake,
  'car': Icons.directions_car,
  'bike': Icons.pedal_bike,
};

// ── Group accent colors (dark-theme friendly) ──

const groupColors = <String, Color>{
  '00E5CC': Color(0xFF00E5CC),
  'FF6B9D': Color(0xFFFF6B9D),
  '7B68EE': Color(0xFF7B68EE),
  'FFA726': Color(0xFFFFA726),
  '42A5F5': Color(0xFF42A5F5),
  'EF5350': Color(0xFFEF5350),
  '66BB6A': Color(0xFF66BB6A),
  'FFEE58': Color(0xFFFFEE58),
  'AB47BC': Color(0xFFAB47BC),
  'FF7043': Color(0xFFFF7043),
  '26C6DA': Color(0xFF26C6DA),
  'EC407A': Color(0xFFEC407A),
};

IconData groupIcon(String key) {
  return groupIcons[key] ?? Icons.group;
}

Color groupColor(String hex) {
  return groupColors[hex] ?? AppColors.accent;
}
