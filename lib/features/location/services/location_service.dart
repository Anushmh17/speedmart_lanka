import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/delivery_location.dart';

class SriLankanSuburb {
  final String name;
  final String city;
  final String district;
  final String province;
  final double latitude;
  final double longitude;

  const SriLankanSuburb({
    required this.name,
    required this.city,
    required this.district,
    required this.province,
    required this.latitude,
    required this.longitude,
  });

  String get displayName => '$name, $city';
}

class LocationService {
  static const double earthRadiusKm = 6371.0;

  /// Comprehensive Sri Lanka locations covering all 9 provinces and 25 districts
  static const List<SriLankanSuburb> sriLankanLocations = [
    // ── Western Province - Colombo District ──────────────────────────────────
    SriLankanSuburb(name: 'Fort', city: 'Colombo 01', district: 'Colombo', province: 'Western', latitude: 6.9344, longitude: 79.8428),
    SriLankanSuburb(name: 'Slave Island', city: 'Colombo 02', district: 'Colombo', province: 'Western', latitude: 6.9213, longitude: 79.8493),
    SriLankanSuburb(name: 'Colpetty', city: 'Colombo 03', district: 'Colombo', province: 'Western', latitude: 6.9145, longitude: 79.8510),
    SriLankanSuburb(name: 'Bambalapitiya', city: 'Colombo 04', district: 'Colombo', province: 'Western', latitude: 6.8990, longitude: 79.8570),
    SriLankanSuburb(name: 'Havelock Town', city: 'Colombo 05', district: 'Colombo', province: 'Western', latitude: 6.8920, longitude: 79.8660),
    SriLankanSuburb(name: 'Wellawatta', city: 'Colombo 06', district: 'Colombo', province: 'Western', latitude: 6.8783, longitude: 79.8620),
    SriLankanSuburb(name: 'Cinnamon Gardens', city: 'Colombo 07', district: 'Colombo', province: 'Western', latitude: 6.9064, longitude: 79.8640),
    SriLankanSuburb(name: 'Borella', city: 'Colombo 08', district: 'Colombo', province: 'Western', latitude: 6.9195, longitude: 79.8750),
    SriLankanSuburb(name: 'Dematagoda', city: 'Colombo 09', district: 'Colombo', province: 'Western', latitude: 6.9345, longitude: 79.8780),
    SriLankanSuburb(name: 'Maradana', city: 'Colombo 10', district: 'Colombo', province: 'Western', latitude: 6.9295, longitude: 79.8658),
    SriLankanSuburb(name: 'Pettah', city: 'Colombo 11', district: 'Colombo', province: 'Western', latitude: 6.9376, longitude: 79.8512),
    SriLankanSuburb(name: 'Kotahena', city: 'Colombo 13', district: 'Colombo', province: 'Western', latitude: 6.9451, longitude: 79.8564),
    SriLankanSuburb(name: 'Grandpass', city: 'Colombo 14', district: 'Colombo', province: 'Western', latitude: 6.9472, longitude: 79.8633),
    SriLankanSuburb(name: 'Modara', city: 'Colombo 15', district: 'Colombo', province: 'Western', latitude: 6.9543, longitude: 79.8640),
    SriLankanSuburb(name: 'Kirulapone', city: 'Colombo', district: 'Colombo', province: 'Western', latitude: 6.8832, longitude: 79.8815),
    SriLankanSuburb(name: 'Nawala', city: 'Nawala', district: 'Colombo', province: 'Western', latitude: 6.8962, longitude: 79.8928),
    SriLankanSuburb(name: 'Dehiwala', city: 'Dehiwala', district: 'Colombo', province: 'Western', latitude: 6.8388, longitude: 79.8767),
    SriLankanSuburb(name: 'Nugegoda', city: 'Nugegoda', district: 'Colombo', province: 'Western', latitude: 6.8745, longitude: 79.8890),
    SriLankanSuburb(name: 'Rajagiriya', city: 'Rajagiriya', district: 'Colombo', province: 'Western', latitude: 6.9100, longitude: 79.8860),
    SriLankanSuburb(name: 'Battaramulla', city: 'Battaramulla', district: 'Colombo', province: 'Western', latitude: 6.8989, longitude: 79.9223),
    SriLankanSuburb(name: 'Mount Lavinia', city: 'Mount Lavinia', district: 'Colombo', province: 'Western', latitude: 6.8340, longitude: 79.8670),
    SriLankanSuburb(name: 'Maharagama', city: 'Maharagama', district: 'Colombo', province: 'Western', latitude: 6.8511, longitude: 79.9212),
    SriLankanSuburb(name: 'Kottawa', city: 'Kottawa', district: 'Colombo', province: 'Western', latitude: 6.8407, longitude: 79.9634),
    SriLankanSuburb(name: 'Hokandara', city: 'Hokandara', district: 'Colombo', province: 'Western', latitude: 6.8561, longitude: 79.9561),
    SriLankanSuburb(name: 'Malabe', city: 'Malabe', district: 'Colombo', province: 'Western', latitude: 6.9028, longitude: 79.9631),
    SriLankanSuburb(name: 'Thalawathugoda', city: 'Thalawathugoda', district: 'Colombo', province: 'Western', latitude: 6.8811, longitude: 79.9287),
    SriLankanSuburb(name: 'Sri Jayawardenepura Kotte', city: 'Kotte', district: 'Colombo', province: 'Western', latitude: 6.8897, longitude: 79.9006),
    SriLankanSuburb(name: 'Kesbewa', city: 'Kesbewa', district: 'Colombo', province: 'Western', latitude: 6.8140, longitude: 79.9436),
    SriLankanSuburb(name: 'Piliyandala', city: 'Piliyandala', district: 'Colombo', province: 'Western', latitude: 6.8009, longitude: 79.9285),
    SriLankanSuburb(name: 'Moratuwa', city: 'Moratuwa', district: 'Colombo', province: 'Western', latitude: 6.7733, longitude: 79.8823),
    SriLankanSuburb(name: 'Angoda', city: 'Angoda', district: 'Colombo', province: 'Western', latitude: 6.9252, longitude: 79.9067),
    SriLankanSuburb(name: 'Kaduwela', city: 'Kaduwela', district: 'Colombo', province: 'Western', latitude: 6.9365, longitude: 79.9786),

    // ── Western Province - Gampaha District ──────────────────────────────────
    SriLankanSuburb(name: 'Gampaha Town', city: 'Gampaha', district: 'Gampaha', province: 'Western', latitude: 7.0897, longitude: 79.9925),
    SriLankanSuburb(name: 'Negombo Town', city: 'Negombo', district: 'Gampaha', province: 'Western', latitude: 7.2089, longitude: 79.8353),
    SriLankanSuburb(name: 'Ja-Ela', city: 'Ja-Ela', district: 'Gampaha', province: 'Western', latitude: 7.0736, longitude: 79.8913),
    SriLankanSuburb(name: 'Wattala', city: 'Wattala', district: 'Gampaha', province: 'Western', latitude: 6.9814, longitude: 79.8927),
    SriLankanSuburb(name: 'Kelaniya', city: 'Kelaniya', district: 'Gampaha', province: 'Western', latitude: 6.9553, longitude: 79.9215),
    SriLankanSuburb(name: 'Peliyagoda', city: 'Peliyagoda', district: 'Gampaha', province: 'Western', latitude: 6.9610, longitude: 79.8989),
    SriLankanSuburb(name: 'Kandana', city: 'Kandana', district: 'Gampaha', province: 'Western', latitude: 7.0405, longitude: 79.8966),
    SriLankanSuburb(name: 'Ragama', city: 'Ragama', district: 'Gampaha', province: 'Western', latitude: 7.0277, longitude: 79.9217),
    SriLankanSuburb(name: 'Divulapitiya', city: 'Divulapitiya', district: 'Gampaha', province: 'Western', latitude: 7.2179, longitude: 80.0327),
    SriLankanSuburb(name: 'Minuwangoda', city: 'Minuwangoda', district: 'Gampaha', province: 'Western', latitude: 7.1665, longitude: 79.9476),
    SriLankanSuburb(name: 'Seeduwa', city: 'Seeduwa', district: 'Gampaha', province: 'Western', latitude: 7.1383, longitude: 79.8876),
    SriLankanSuburb(name: 'Katana', city: 'Katana', district: 'Gampaha', province: 'Western', latitude: 7.1580, longitude: 79.8655),
    SriLankanSuburb(name: 'Nittambuwa', city: 'Nittambuwa', district: 'Gampaha', province: 'Western', latitude: 7.1466, longitude: 80.1087),
    SriLankanSuburb(name: 'Veyangoda', city: 'Veyangoda', district: 'Gampaha', province: 'Western', latitude: 7.1488, longitude: 80.0131),
    SriLankanSuburb(name: 'Mirigama', city: 'Mirigama', district: 'Gampaha', province: 'Western', latitude: 7.2358, longitude: 80.0826),
    SriLankanSuburb(name: 'Katunayake', city: 'Katunayake', district: 'Gampaha', province: 'Western', latitude: 7.1683, longitude: 79.8866),
    SriLankanSuburb(name: 'Biyagama', city: 'Biyagama', district: 'Gampaha', province: 'Western', latitude: 6.9796, longitude: 79.9545),

    // ── Western Province - Kalutara District ──────────────────────────────────
    SriLankanSuburb(name: 'Kalutara Town', city: 'Kalutara', district: 'Kalutara', province: 'Western', latitude: 6.5854, longitude: 79.9607),
    SriLankanSuburb(name: 'Panadura', city: 'Panadura', district: 'Kalutara', province: 'Western', latitude: 6.7119, longitude: 79.9074),
    SriLankanSuburb(name: 'Horana', city: 'Horana', district: 'Kalutara', province: 'Western', latitude: 6.7196, longitude: 80.0628),
    SriLankanSuburb(name: 'Beruwala', city: 'Beruwala', district: 'Kalutara', province: 'Western', latitude: 6.4771, longitude: 79.9834),
    SriLankanSuburb(name: 'Aluthgama', city: 'Aluthgama', district: 'Kalutara', province: 'Western', latitude: 6.4296, longitude: 80.0046),
    SriLankanSuburb(name: 'Matugama', city: 'Matugama', district: 'Kalutara', province: 'Western', latitude: 6.5432, longitude: 80.1188),
    SriLankanSuburb(name: 'Ingiriya', city: 'Ingiriya', district: 'Kalutara', province: 'Western', latitude: 6.6592, longitude: 80.1618),
    SriLankanSuburb(name: 'Wadduwa', city: 'Wadduwa', district: 'Kalutara', province: 'Western', latitude: 6.6711, longitude: 79.9370),

    // ── Central Province - Kandy District ────────────────────────────────────
    SriLankanSuburb(name: 'Kandy Town', city: 'Kandy', district: 'Kandy', province: 'Central', latitude: 7.2906, longitude: 80.6337),
    SriLankanSuburb(name: 'Peradeniya', city: 'Peradeniya', district: 'Kandy', province: 'Central', latitude: 7.2681, longitude: 80.5966),
    SriLankanSuburb(name: 'Katugastota', city: 'Katugastota', district: 'Kandy', province: 'Central', latitude: 7.3270, longitude: 80.6195),
    SriLankanSuburb(name: 'Kundasale', city: 'Kundasale', district: 'Kandy', province: 'Central', latitude: 7.3009, longitude: 80.6858),
    SriLankanSuburb(name: 'Pilimathalawa', city: 'Pilimathalawa', district: 'Kandy', province: 'Central', latitude: 7.2554, longitude: 80.5716),
    SriLankanSuburb(name: 'Gampola', city: 'Gampola', district: 'Kandy', province: 'Central', latitude: 7.1650, longitude: 80.5742),
    SriLankanSuburb(name: 'Nawalapitiya', city: 'Nawalapitiya', district: 'Kandy', province: 'Central', latitude: 7.0557, longitude: 80.5375),
    SriLankanSuburb(name: 'Wattegama', city: 'Wattegama', district: 'Kandy', province: 'Central', latitude: 7.3700, longitude: 80.6940),
    SriLankanSuburb(name: 'Digana', city: 'Digana', district: 'Kandy', province: 'Central', latitude: 7.2867, longitude: 80.7439),

    // ── Central Province - Matale District ───────────────────────────────────
    SriLankanSuburb(name: 'Matale Town', city: 'Matale', district: 'Matale', province: 'Central', latitude: 7.4675, longitude: 80.6234),
    SriLankanSuburb(name: 'Dambulla', city: 'Dambulla', district: 'Matale', province: 'Central', latitude: 7.8608, longitude: 80.6517),
    SriLankanSuburb(name: 'Galewela', city: 'Galewela', district: 'Matale', province: 'Central', latitude: 7.7413, longitude: 80.6326),
    SriLankanSuburb(name: 'Rattota', city: 'Rattota', district: 'Matale', province: 'Central', latitude: 7.5292, longitude: 80.7109),

    // ── Central Province - Nuwara Eliya District ─────────────────────────────
    SriLankanSuburb(name: 'Nuwara Eliya Town', city: 'Nuwara Eliya', district: 'Nuwara Eliya', province: 'Central', latitude: 6.9497, longitude: 80.7891),
    SriLankanSuburb(name: 'Hatton', city: 'Hatton', district: 'Nuwara Eliya', province: 'Central', latitude: 6.8908, longitude: 80.5986),
    SriLankanSuburb(name: 'Talawakele', city: 'Talawakele', district: 'Nuwara Eliya', province: 'Central', latitude: 6.9330, longitude: 80.6556),
    SriLankanSuburb(name: 'Kotagala', city: 'Kotagala', district: 'Nuwara Eliya', province: 'Central', latitude: 6.9118, longitude: 80.6287),

    // ── Southern Province - Galle District ───────────────────────────────────
    SriLankanSuburb(name: 'Galle Fort', city: 'Galle', district: 'Galle', province: 'Southern', latitude: 6.0535, longitude: 80.2210),
    SriLankanSuburb(name: 'Galle City', city: 'Galle', district: 'Galle', province: 'Southern', latitude: 6.0367, longitude: 80.2170),
    SriLankanSuburb(name: 'Hikkaduwa', city: 'Hikkaduwa', district: 'Galle', province: 'Southern', latitude: 6.1398, longitude: 80.1060),
    SriLankanSuburb(name: 'Ambalangoda', city: 'Ambalangoda', district: 'Galle', province: 'Southern', latitude: 6.2348, longitude: 80.0597),
    SriLankanSuburb(name: 'Elpitiya', city: 'Elpitiya', district: 'Galle', province: 'Southern', latitude: 6.2886, longitude: 80.1616),
    SriLankanSuburb(name: 'Karandeniya', city: 'Karandeniya', district: 'Galle', province: 'Southern', latitude: 6.2066, longitude: 80.1557),
    SriLankanSuburb(name: 'Baddegama', city: 'Baddegama', district: 'Galle', province: 'Southern', latitude: 6.1797, longitude: 80.2115),

    // ── Southern Province - Matara District ──────────────────────────────────
    SriLankanSuburb(name: 'Matara Town', city: 'Matara', district: 'Matara', province: 'Southern', latitude: 5.9549, longitude: 80.5550),
    SriLankanSuburb(name: 'Weligama', city: 'Weligama', district: 'Matara', province: 'Southern', latitude: 5.9722, longitude: 80.4289),
    SriLankanSuburb(name: 'Mirissa', city: 'Mirissa', district: 'Matara', province: 'Southern', latitude: 5.9486, longitude: 80.4572),
    SriLankanSuburb(name: 'Akuressa', city: 'Akuressa', district: 'Matara', province: 'Southern', latitude: 6.1067, longitude: 80.4835),
    SriLankanSuburb(name: 'Hakmana', city: 'Hakmana', district: 'Matara', province: 'Southern', latitude: 6.0660, longitude: 80.6040),
    SriLankanSuburb(name: 'Deniyaya', city: 'Deniyaya', district: 'Matara', province: 'Southern', latitude: 6.3468, longitude: 80.5520),

    // ── Southern Province - Hambantota District ───────────────────────────────
    SriLankanSuburb(name: 'Hambantota Town', city: 'Hambantota', district: 'Hambantota', province: 'Southern', latitude: 6.1248, longitude: 81.1185),
    SriLankanSuburb(name: 'Tangalle', city: 'Tangalle', district: 'Hambantota', province: 'Southern', latitude: 6.0242, longitude: 80.7937),
    SriLankanSuburb(name: 'Tissamaharama', city: 'Tissamaharama', district: 'Hambantota', province: 'Southern', latitude: 6.2869, longitude: 81.2881),
    SriLankanSuburb(name: 'Ambalantota', city: 'Ambalantota', district: 'Hambantota', province: 'Southern', latitude: 6.1167, longitude: 81.0219),
    SriLankanSuburb(name: 'Beliatta', city: 'Beliatta', district: 'Hambantota', province: 'Southern', latitude: 6.0389, longitude: 80.9237),

    // ── Northern Province - Jaffna District ──────────────────────────────────
    SriLankanSuburb(name: 'Jaffna Town', city: 'Jaffna', district: 'Jaffna', province: 'Northern', latitude: 9.6615, longitude: 80.0125),
    SriLankanSuburb(name: 'Nallur', city: 'Nallur', district: 'Jaffna', province: 'Northern', latitude: 9.6744, longitude: 80.0319),
    SriLankanSuburb(name: 'Chavakachcheri', city: 'Chavakachcheri', district: 'Jaffna', province: 'Northern', latitude: 9.6578, longitude: 80.1556),
    SriLankanSuburb(name: 'Point Pedro', city: 'Point Pedro', district: 'Jaffna', province: 'Northern', latitude: 9.8199, longitude: 80.2371),
    SriLankanSuburb(name: 'Kopay', city: 'Kopay', district: 'Jaffna', province: 'Northern', latitude: 9.7038, longitude: 80.0571),

    // ── Northern Province - Kilinochchi District ──────────────────────────────
    SriLankanSuburb(name: 'Kilinochchi Town', city: 'Kilinochchi', district: 'Kilinochchi', province: 'Northern', latitude: 9.3803, longitude: 80.3986),

    // ── Northern Province - Mannar District ──────────────────────────────────
    SriLankanSuburb(name: 'Mannar Town', city: 'Mannar', district: 'Mannar', province: 'Northern', latitude: 8.9810, longitude: 79.9054),

    // ── Northern Province - Vavuniya District ─────────────────────────────────
    SriLankanSuburb(name: 'Vavuniya Town', city: 'Vavuniya', district: 'Vavuniya', province: 'Northern', latitude: 8.7514, longitude: 80.4971),
    SriLankanSuburb(name: 'Cheddikulam', city: 'Cheddikulam', district: 'Vavuniya', province: 'Northern', latitude: 8.9332, longitude: 80.3133),

    // ── Northern Province - Mullaitivu District ───────────────────────────────
    SriLankanSuburb(name: 'Mullaitivu Town', city: 'Mullaitivu', district: 'Mullaitivu', province: 'Northern', latitude: 9.2662, longitude: 80.8143),

    // ── Eastern Province - Trincomalee District ───────────────────────────────
    SriLankanSuburb(name: 'Trincomalee Town', city: 'Trincomalee', district: 'Trincomalee', province: 'Eastern', latitude: 8.5711, longitude: 81.2335),
    SriLankanSuburb(name: 'Kinniya', city: 'Kinniya', district: 'Trincomalee', province: 'Eastern', latitude: 8.6302, longitude: 81.2189),
    SriLankanSuburb(name: 'Mutur', city: 'Mutur', district: 'Trincomalee', province: 'Eastern', latitude: 8.4490, longitude: 81.2658),

    // ── Eastern Province - Batticaloa District ────────────────────────────────
    SriLankanSuburb(name: 'Batticaloa Town', city: 'Batticaloa', district: 'Batticaloa', province: 'Eastern', latitude: 7.7170, longitude: 81.7010),
    SriLankanSuburb(name: 'Kattankudy', city: 'Kattankudy', district: 'Batticaloa', province: 'Eastern', latitude: 7.6697, longitude: 81.6930),
    SriLankanSuburb(name: 'Valaichchenai', city: 'Valaichchenai', district: 'Batticaloa', province: 'Eastern', latitude: 7.9983, longitude: 81.5453),

    // ── Eastern Province - Ampara District ────────────────────────────────────
    SriLankanSuburb(name: 'Ampara Town', city: 'Ampara', district: 'Ampara', province: 'Eastern', latitude: 7.2882, longitude: 81.6747),
    SriLankanSuburb(name: 'Kalmunai', city: 'Kalmunai', district: 'Ampara', province: 'Eastern', latitude: 7.4166, longitude: 81.8271),
    SriLankanSuburb(name: 'Akkaraipattu', city: 'Akkaraipattu', district: 'Ampara', province: 'Eastern', latitude: 7.2159, longitude: 81.8422),
    SriLankanSuburb(name: 'Samanthurai', city: 'Samanthurai', district: 'Ampara', province: 'Eastern', latitude: 7.3620, longitude: 81.8043),

    // ── North Western Province - Kurunegala District ──────────────────────────
    SriLankanSuburb(name: 'Kurunegala Town', city: 'Kurunegala', district: 'Kurunegala', province: 'North Western', latitude: 7.4863, longitude: 80.3647),
    SriLankanSuburb(name: 'Wariyapola', city: 'Wariyapola', district: 'Kurunegala', province: 'North Western', latitude: 7.6049, longitude: 80.2201),
    SriLankanSuburb(name: 'Kuliyapitiya', city: 'Kuliyapitiya', district: 'Kurunegala', province: 'North Western', latitude: 7.4686, longitude: 80.0414),
    SriLankanSuburb(name: 'Maho', city: 'Maho', district: 'Kurunegala', province: 'North Western', latitude: 7.8995, longitude: 80.2888),
    SriLankanSuburb(name: 'Nikaweratiya', city: 'Nikaweratiya', district: 'Kurunegala', province: 'North Western', latitude: 7.7462, longitude: 80.1188),
    SriLankanSuburb(name: 'Pannala', city: 'Pannala', district: 'Kurunegala', province: 'North Western', latitude: 7.3371, longitude: 80.0361),
    SriLankanSuburb(name: 'Narammala', city: 'Narammala', district: 'Kurunegala', province: 'North Western', latitude: 7.3590, longitude: 80.2152),
    SriLankanSuburb(name: 'Alawwa', city: 'Alawwa', district: 'Kurunegala', province: 'North Western', latitude: 7.2745, longitude: 80.2430),

    // ── North Western Province - Puttalam District ────────────────────────────
    SriLankanSuburb(name: 'Puttalam Town', city: 'Puttalam', district: 'Puttalam', province: 'North Western', latitude: 8.0330, longitude: 79.8267),
    SriLankanSuburb(name: 'Chilaw', city: 'Chilaw', district: 'Puttalam', province: 'North Western', latitude: 7.5759, longitude: 79.7952),
    SriLankanSuburb(name: 'Wennappuwa', city: 'Wennappuwa', district: 'Puttalam', province: 'North Western', latitude: 7.3665, longitude: 79.8546),
    SriLankanSuburb(name: 'Marawila', city: 'Marawila', district: 'Puttalam', province: 'North Western', latitude: 7.4934, longitude: 79.8462),
    SriLankanSuburb(name: 'Nattandiya', city: 'Nattandiya', district: 'Puttalam', province: 'North Western', latitude: 7.4268, longitude: 79.8701),

    // ── North Central Province - Anuradhapura District ────────────────────────
    SriLankanSuburb(name: 'Anuradhapura City', city: 'Anuradhapura', district: 'Anuradhapura', province: 'North Central', latitude: 8.3114, longitude: 80.4037),
    SriLankanSuburb(name: 'Medawachchiya', city: 'Medawachchiya', district: 'Anuradhapura', province: 'North Central', latitude: 8.5448, longitude: 80.4966),
    SriLankanSuburb(name: 'Kekirawa', city: 'Kekirawa', district: 'Anuradhapura', province: 'North Central', latitude: 8.0264, longitude: 80.5978),
    SriLankanSuburb(name: 'Tambuttegama', city: 'Tambuttegama', district: 'Anuradhapura', province: 'North Central', latitude: 8.1026, longitude: 80.3911),

    // ── North Central Province - Polonnaruwa District ─────────────────────────
    SriLankanSuburb(name: 'Polonnaruwa Town', city: 'Polonnaruwa', district: 'Polonnaruwa', province: 'North Central', latitude: 7.9397, longitude: 81.0022),
    SriLankanSuburb(name: 'Hingurakgoda', city: 'Hingurakgoda', district: 'Polonnaruwa', province: 'North Central', latitude: 7.9979, longitude: 81.0395),
    SriLankanSuburb(name: 'Kaduruwela', city: 'Kaduruwela', district: 'Polonnaruwa', province: 'North Central', latitude: 7.9497, longitude: 81.0175),

    // ── Uva Province - Badulla District ───────────────────────────────────────
    SriLankanSuburb(name: 'Badulla Town', city: 'Badulla', district: 'Badulla', province: 'Uva', latitude: 6.9934, longitude: 81.0550),
    SriLankanSuburb(name: 'Bandarawela', city: 'Bandarawela', district: 'Badulla', province: 'Uva', latitude: 6.8259, longitude: 80.9981),
    SriLankanSuburb(name: 'Ella', city: 'Ella', district: 'Badulla', province: 'Uva', latitude: 6.8760, longitude: 81.0460),
    SriLankanSuburb(name: 'Hali-Ela', city: 'Hali-Ela', district: 'Badulla', province: 'Uva', latitude: 6.9525, longitude: 81.0382),
    SriLankanSuburb(name: 'Welimada', city: 'Welimada', district: 'Badulla', province: 'Uva', latitude: 6.9005, longitude: 80.9164),
    SriLankanSuburb(name: 'Mahiyanganaya', city: 'Mahiyanganaya', district: 'Badulla', province: 'Uva', latitude: 7.3521, longitude: 81.0020),

    // ── Uva Province - Monaragala District ────────────────────────────────────
    SriLankanSuburb(name: 'Monaragala Town', city: 'Monaragala', district: 'Monaragala', province: 'Uva', latitude: 6.8719, longitude: 81.3503),
    SriLankanSuburb(name: 'Wellawaya', city: 'Wellawaya', district: 'Monaragala', province: 'Uva', latitude: 6.7381, longitude: 81.1032),
    SriLankanSuburb(name: 'Bibile', city: 'Bibile', district: 'Monaragala', province: 'Uva', latitude: 7.1633, longitude: 81.2159),

    // ── Sabaragamuwa Province - Ratnapura District ────────────────────────────
    SriLankanSuburb(name: 'Ratnapura Town', city: 'Ratnapura', district: 'Ratnapura', province: 'Sabaragamuwa', latitude: 6.6828, longitude: 80.3992),
    SriLankanSuburb(name: 'Embilipitiya', city: 'Embilipitiya', district: 'Ratnapura', province: 'Sabaragamuwa', latitude: 6.3423, longitude: 80.8436),
    SriLankanSuburb(name: 'Balangoda', city: 'Balangoda', district: 'Ratnapura', province: 'Sabaragamuwa', latitude: 6.6505, longitude: 80.6990),
    SriLankanSuburb(name: 'Eheliyagoda', city: 'Eheliyagoda', district: 'Ratnapura', province: 'Sabaragamuwa', latitude: 6.8499, longitude: 80.2358),
    SriLankanSuburb(name: 'Kuruwita', city: 'Kuruwita', district: 'Ratnapura', province: 'Sabaragamuwa', latitude: 6.7733, longitude: 80.3571),

    // ── Sabaragamuwa Province - Kegalle District ──────────────────────────────
    SriLankanSuburb(name: 'Kegalle Town', city: 'Kegalle', district: 'Kegalle', province: 'Sabaragamuwa', latitude: 7.2513, longitude: 80.3464),
    SriLankanSuburb(name: 'Mawanella', city: 'Mawanella', district: 'Kegalle', province: 'Sabaragamuwa', latitude: 7.2534, longitude: 80.4551),
    SriLankanSuburb(name: 'Warakapola', city: 'Warakapola', district: 'Kegalle', province: 'Sabaragamuwa', latitude: 7.2517, longitude: 80.1797),
    SriLankanSuburb(name: 'Rambukkana', city: 'Rambukkana', district: 'Kegalle', province: 'Sabaragamuwa', latitude: 7.3291, longitude: 80.4161),
    SriLankanSuburb(name: 'Dehiowita', city: 'Dehiowita', district: 'Kegalle', province: 'Sabaragamuwa', latitude: 6.9459, longitude: 80.2307),
  ];

  /// Computes distance in kilometers between two sets of coordinates using the Haversine Formula
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Reverse geocode given coordinates to the nearest Sri Lankan suburb.
  /// streetAddress can optionally be provided (e.g. for mock data / GPS updates), defaulting to empty.
  static const double _maxMatchDistanceKm = 25.0;

  static DeliveryLocation? tryReverseGeocode({
    required double latitude,
    required double longitude,
    String streetAddress = '',
    bool isManualOverride = false,
  }) {
    SriLankanSuburb? nearest;
    double minDistance = double.maxFinite;

    for (final loc in sriLankanLocations) {
      final dist = calculateDistance(
        lat1: latitude,
        lon1: longitude,
        lat2: loc.latitude,
        lon2: loc.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = loc;
      }
    }

    if (nearest == null || minDistance > _maxMatchDistanceKm) return null;

    final String formatted =
        '${nearest.name}, ${nearest.city}, ${nearest.district} District, ${nearest.province} Province';

    return DeliveryLocation(
      province: nearest.province,
      district: nearest.district,
      city: nearest.city,
      suburb: nearest.name,
      formattedAddress: formatted,
      streetAddress: streetAddress,
      latitude: latitude,
      longitude: longitude,
      isGpsDetected: !isManualOverride,
      isManualOverride: isManualOverride,
    );
  }

  static DeliveryLocation reverseGeocode({
    required double latitude,
    required double longitude,
    String streetAddress = '',
    bool isManualOverride = false,
  }) {
    SriLankanSuburb nearest = sriLankanLocations.first;
    double minDistance = double.maxFinite;

    for (final loc in sriLankanLocations) {
      final dist = calculateDistance(
        lat1: latitude,
        lon1: longitude,
        lat2: loc.latitude,
        lon2: loc.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = loc;
      }
    }

    if (minDistance > _maxMatchDistanceKm) {
      return DeliveryLocation(
        province: '',
        district: '',
        city: '',
        suburb: '',
        formattedAddress: '',
        streetAddress: streetAddress,
        latitude: latitude,
        longitude: longitude,
        isGpsDetected: !isManualOverride,
        isManualOverride: isManualOverride,
      );
    }

    final String formatted =
        '${nearest.name}, ${nearest.city}, ${nearest.district} District, ${nearest.province} Province';

    return DeliveryLocation(
      province: nearest.province,
      district: nearest.district,
      city: nearest.city,
      suburb: nearest.name,
      formattedAddress: formatted,
      streetAddress: streetAddress, // User must enter their own precise address or use the mock/passed value
      latitude: latitude,
      longitude: longitude,
      isGpsDetected: !isManualOverride,
      isManualOverride: isManualOverride,
    );
  }

  /// Resolve suburb details directly by suburb/city name (manual dropdown selection).
  /// streetAddress is left empty — user must type their own precise address.
  static DeliveryLocation selectSuburb(SriLankanSuburb suburb) {
    final String formatted =
        '${suburb.name}, ${suburb.city}, ${suburb.district} District, ${suburb.province} Province';
    return DeliveryLocation(
      province: suburb.province,
      district: suburb.district,
      city: suburb.city,
      suburb: suburb.name,
      formattedAddress: formatted,
      streetAddress: '', // User must enter their own precise address
      latitude: suburb.latitude,
      longitude: suburb.longitude,
      isGpsDetected: false,
      isManualOverride: true,
    );
  }

  /// Search matching Sri Lankan suburbs by query (name, city, district, or province)
  static List<SriLankanSuburb> searchSuburbs(String query) {
    if (query.trim().isEmpty) return sriLankanLocations.take(15).toList();
    final lower = query.toLowerCase().trim();
    return sriLankanLocations.where((loc) {
      return loc.name.toLowerCase().contains(lower) ||
          loc.city.toLowerCase().contains(lower) ||
          loc.district.toLowerCase().contains(lower) ||
          loc.province.toLowerCase().contains(lower);
    }).toList();
  }

  /// Generate a Google Maps URL for direct device navigation
  static String getGoogleMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  /// Open map with location coordinates using platform-specific handlers
  /// Tries geo: URI first (native maps), falls back to Google Maps web
  /// Validates coordinates before attempting to open
  static Future<void> openMap({
    required double latitude,
    required double longitude,
  }) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw Exception('Invalid coordinates: latitude must be between -90 and 90, longitude between -180 and 180');
    }

    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
    final googleMapsWebUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[LocationService] Geo URI launch failed: $e');
    }

    try {
      if (await canLaunchUrl(googleMapsWebUri)) {
        await launchUrl(googleMapsWebUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[LocationService] Google Maps web launch failed: $e');
    }

    throw Exception('Could not open maps - no suitable app or browser available');
  }
}

