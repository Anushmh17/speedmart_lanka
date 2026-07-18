import '../models/sri_lanka_district.dart';
import '../models/sri_lanka_province.dart';

/// Complete static dataset for all 9 Sri Lanka provinces and 25 districts.
///
/// IDs are stable integers — do not change them; they may be stored
/// in Firestore / SharedPreferences as references.
///
/// No coordinates here — this is purely administrative data.
/// Coordinates live inside [LocationService] suburb entries when needed.
class SriLankaData {
  SriLankaData._();

  // ── Province IDs ───────────────────────────────────────────────────────────
  static const int westernId       = 1;
  static const int centralId       = 2;
  static const int southernId      = 3;
  static const int northernId      = 4;
  static const int easternId       = 5;
  static const int northWesternId  = 6;
  static const int northCentralId  = 7;
  static const int uvaId           = 8;
  static const int sabaragamuwaId  = 9;

  // ── District IDs ──────────────────────────────────────────────────────────
  // Western
  static const int colomboId       = 101;
  static const int gampahaId       = 102;
  static const int kalutaraId      = 103;
  // Central
  static const int kandyId         = 201;
  static const int mataleId        = 202;
  static const int nuwaraEliyaId   = 203;
  // Southern
  static const int galleId         = 301;
  static const int mataraId        = 302;
  static const int hambantotaId    = 303;
  // Northern
  static const int jaffnaId        = 401;
  static const int kilinochchiId   = 402;
  static const int mannarId        = 403;
  static const int mullaitivuId    = 404;
  static const int vavuniyaId      = 405;
  // Eastern
  static const int batticaloadId   = 501;
  static const int amparaId        = 502;
  static const int trincomaleeId   = 503;
  // North Western
  static const int kurunegalaId    = 601;
  static const int puttalamId      = 602;
  // North Central
  static const int anuradhapuraId  = 701;
  static const int polonnaruwaId   = 702;
  // Uva
  static const int badullaId       = 801;
  static const int monaragalaId    = 802;
  // Sabaragamuwa
  static const int ratnapuraId     = 901;
  static const int kegalleId       = 902;

  // ── Districts ─────────────────────────────────────────────────────────────

  static const SriLankaDistrict colombo = SriLankaDistrict(
      id: colomboId, provinceId: westernId, name: 'Colombo');
  static const SriLankaDistrict gampaha = SriLankaDistrict(
      id: gampahaId, provinceId: westernId, name: 'Gampaha');
  static const SriLankaDistrict kalutara = SriLankaDistrict(
      id: kalutaraId, provinceId: westernId, name: 'Kalutara');

  static const SriLankaDistrict kandy = SriLankaDistrict(
      id: kandyId, provinceId: centralId, name: 'Kandy');
  static const SriLankaDistrict matale = SriLankaDistrict(
      id: mataleId, provinceId: centralId, name: 'Matale');
  static const SriLankaDistrict nuwaraEliya = SriLankaDistrict(
      id: nuwaraEliyaId, provinceId: centralId, name: 'Nuwara Eliya');

  static const SriLankaDistrict galle = SriLankaDistrict(
      id: galleId, provinceId: southernId, name: 'Galle');
  static const SriLankaDistrict matara = SriLankaDistrict(
      id: mataraId, provinceId: southernId, name: 'Matara');
  static const SriLankaDistrict hambantota = SriLankaDistrict(
      id: hambantotaId, provinceId: southernId, name: 'Hambantota');

  static const SriLankaDistrict jaffna = SriLankaDistrict(
      id: jaffnaId, provinceId: northernId, name: 'Jaffna');
  static const SriLankaDistrict kilinochchi = SriLankaDistrict(
      id: kilinochchiId, provinceId: northernId, name: 'Kilinochchi');
  static const SriLankaDistrict mannar = SriLankaDistrict(
      id: mannarId, provinceId: northernId, name: 'Mannar');
  static const SriLankaDistrict mullaitivu = SriLankaDistrict(
      id: mullaitivuId, provinceId: northernId, name: 'Mullaitivu');
  static const SriLankaDistrict vavuniya = SriLankaDistrict(
      id: vavuniyaId, provinceId: northernId, name: 'Vavuniya');

  static const SriLankaDistrict batticaloa = SriLankaDistrict(
      id: batticaloadId, provinceId: easternId, name: 'Batticaloa');
  static const SriLankaDistrict ampara = SriLankaDistrict(
      id: amparaId, provinceId: easternId, name: 'Ampara');
  static const SriLankaDistrict trincomalee = SriLankaDistrict(
      id: trincomaleeId, provinceId: easternId, name: 'Trincomalee');

  static const SriLankaDistrict kurunegala = SriLankaDistrict(
      id: kurunegalaId, provinceId: northWesternId, name: 'Kurunegala');
  static const SriLankaDistrict puttalam = SriLankaDistrict(
      id: puttalamId, provinceId: northWesternId, name: 'Puttalam');

  static const SriLankaDistrict anuradhapura = SriLankaDistrict(
      id: anuradhapuraId, provinceId: northCentralId, name: 'Anuradhapura');
  static const SriLankaDistrict polonnaruwa = SriLankaDistrict(
      id: polonnaruwaId, provinceId: northCentralId, name: 'Polonnaruwa');

  static const SriLankaDistrict badulla = SriLankaDistrict(
      id: badullaId, provinceId: uvaId, name: 'Badulla');
  static const SriLankaDistrict monaragala = SriLankaDistrict(
      id: monaragalaId, provinceId: uvaId, name: 'Monaragala');

  static const SriLankaDistrict ratnapura = SriLankaDistrict(
      id: ratnapuraId, provinceId: sabaragamuwaId, name: 'Ratnapura');
  static const SriLankaDistrict kegalle = SriLankaDistrict(
      id: kegalleId, provinceId: sabaragamuwaId, name: 'Kegalle');

  // ── Provinces (with nested districts) ─────────────────────────────────────

  static const SriLankaProvince western = SriLankaProvince(
    id: westernId,
    name: 'Western',
    districts: [colombo, gampaha, kalutara],
  );

  static const SriLankaProvince central = SriLankaProvince(
    id: centralId,
    name: 'Central',
    districts: [kandy, matale, nuwaraEliya],
  );

  static const SriLankaProvince southern = SriLankaProvince(
    id: southernId,
    name: 'Southern',
    districts: [galle, matara, hambantota],
  );

  static const SriLankaProvince northern = SriLankaProvince(
    id: northernId,
    name: 'Northern',
    districts: [jaffna, kilinochchi, mannar, mullaitivu, vavuniya],
  );

  static const SriLankaProvince eastern = SriLankaProvince(
    id: easternId,
    name: 'Eastern',
    districts: [batticaloa, ampara, trincomalee],
  );

  static const SriLankaProvince northWestern = SriLankaProvince(
    id: northWesternId,
    name: 'North Western',
    districts: [kurunegala, puttalam],
  );

  static const SriLankaProvince northCentral = SriLankaProvince(
    id: northCentralId,
    name: 'North Central',
    districts: [anuradhapura, polonnaruwa],
  );

  static const SriLankaProvince uva = SriLankaProvince(
    id: uvaId,
    name: 'Uva',
    districts: [badulla, monaragala],
  );

  static const SriLankaProvince sabaragamuwa = SriLankaProvince(
    id: sabaragamuwaId,
    name: 'Sabaragamuwa',
    districts: [ratnapura, kegalle],
  );

  /// All 9 provinces in display order.
  static const List<SriLankaProvince> provinces = [
    western,
    central,
    southern,
    northern,
    eastern,
    northWestern,
    northCentral,
    uva,
    sabaragamuwa,
  ];

  /// All 25 districts (flat list).
  static const List<SriLankaDistrict> districts = [
    colombo, gampaha, kalutara,
    kandy, matale, nuwaraEliya,
    galle, matara, hambantota,
    jaffna, kilinochchi, mannar, mullaitivu, vavuniya,
    batticaloa, ampara, trincomalee,
    kurunegala, puttalam,
    anuradhapura, polonnaruwa,
    badulla, monaragala,
    ratnapura, kegalle,
  ];

  // ── Lookup Helpers ─────────────────────────────────────────────────────────

  /// Find a province by its id. Returns null if not found.
  static SriLankaProvince? provinceById(int id) {
    try {
      return provinces.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find a district by its id. Returns null if not found.
  static SriLankaDistrict? districtById(int id) {
    try {
      return districts.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find a province by name (case-insensitive). Returns null if not found.
  static SriLankaProvince? provinceByName(String name) {
    final lower = name.toLowerCase().trim();
    try {
      return provinces.firstWhere((p) => p.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  /// Find a district by name (case-insensitive). Returns null if not found.
  static SriLankaDistrict? districtByName(String name) {
    final lower = name.toLowerCase().trim();
    try {
      return districts.firstWhere((d) => d.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  /// All districts that belong to a given province id.
  static List<SriLankaDistrict> districtsForProvince(int provinceId) {
    return districts.where((d) => d.provinceId == provinceId).toList();
  }

  /// Search provinces and districts by query string.
  /// Returns a flat list of matching names (used for autocomplete).
  static List<String> searchNames(String query) {
    if (query.trim().isEmpty) return [];
    final lower = query.toLowerCase().trim();
    final results = <String>[];

    for (final p in provinces) {
      if (p.name.toLowerCase().contains(lower)) results.add(p.name);
      for (final d in p.districts) {
        if (d.name.toLowerCase().contains(lower)) {
          results.add('${d.name}, ${p.name}');
        }
      }
    }
    return results;
  }
}

