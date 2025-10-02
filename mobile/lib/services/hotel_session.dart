import 'package:flutter/foundation.dart';

class HotelSession {
  static int? hotelId;
  static String? hotelName;

  // 🔔 notifica cambios de nombre de hotel
  static final ValueNotifier<String?> notifier = ValueNotifier<String?>(null);

  static void set(int id, String? name) {
    hotelId = id;
    hotelName = name;
    notifier.value = hotelName;
  }

  static void clear() {
    hotelId = null;
    hotelName = null;
    notifier.value = null;
  }

  static bool get hasHotel => hotelId != null;
}
