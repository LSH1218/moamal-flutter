import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _studentNameKey = 'studentName';
  static const _joinedCodeKey = 'joinedSessionCode';

  final SharedPreferences _prefs;

  LocalStore(this._prefs);

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  String getStudentName() => _prefs.getString(_studentNameKey) ?? '';
  Future<void> saveStudentName(String name) =>
      _prefs.setString(_studentNameKey, name);
  Future<void> clearStudentName() => _prefs.remove(_studentNameKey);

  String? getJoinedSessionCode() => _prefs.getString(_joinedCodeKey);
  Future<void> saveJoinedSessionCode(String code) =>
      _prefs.setString(_joinedCodeKey, code);
  Future<void> clearJoinedSessionCode() => _prefs.remove(_joinedCodeKey);
}
