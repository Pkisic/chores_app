import 'package:flutter/material.dart';

/// A curated set of icons usable for chores.
/// Maps a string key → IconData so we can persist the key in Firestore
/// and reconstruct the icon at runtime.
class ChoreIcons {
  ChoreIcons._();

  static const Map<String, IconData> all = {
    'clean': Icons.cleaning_services,
    'kitchen': Icons.kitchen,
    'laundry': Icons.local_laundry_service,
    'vacuum': Icons.air,
    'dishes': Icons.soup_kitchen,
    'trash': Icons.delete_outline,
    'groceries': Icons.shopping_cart,
    'cook': Icons.restaurant,
    'mop': Icons.water_drop,
    'dust': Icons.blur_on,
    'iron': Icons.iron,
    'bed': Icons.bed,
    'bathroom': Icons.bathtub,
    'garden': Icons.yard,
    'pet': Icons.pets,
    'recycle': Icons.recycling,
    'repair': Icons.build,
    'organize': Icons.inventory_2,
    'windows': Icons.window,
    'car': Icons.directions_car,
    'mail': Icons.mail,
    'plant': Icons.local_florist,
    'sweep': Icons.cleaning_services_outlined,
    'fold': Icons.checkroom,
  };

  static IconData fromKey(String key) =>
      all[key] ?? Icons.cleaning_services;

  static String keyFromIconData(IconData icon) {
    for (final entry in all.entries) {
      if (entry.value == icon) return entry.key;
    }
    return 'clean';
  }
}

/// Curated colour palette for chores.
class ChoreColors {
  ChoreColors._();

  static const List<String> palette = [
    '#FF6B6B', // coral
    '#4ECDC4', // teal
    '#45B7D1', // sky blue
    '#96CEB4', // sage
    '#FFEAA7', // lemon
    '#DDA0DD', // plum
    '#FF8C42', // tangerine
    '#98D8C8', // mint
    '#F7DC6F', // gold
    '#BB8FCE', // lavender
    '#F1948A', // salmon
    '#7FB3D8', // powder blue
    '#82E0AA', // emerald
    '#F0B27A', // peach
    '#AED6F1', // ice blue
    '#D7BDE2', // mauve
  ];

  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) buffer.write('FF');
    buffer.write(hex);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}

/// Weekday helpers (ISO 8601: 1=Monday … 7=Sunday).
class Weekdays {
  Weekdays._();

  static const List<String> shortNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> fullNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String shortName(int day) => shortNames[day - 1];
  static String fullName(int day) => fullNames[day - 1];
}
