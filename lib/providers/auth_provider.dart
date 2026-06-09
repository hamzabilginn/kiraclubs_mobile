import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String?   _token;
  bool      _isLoading       = false;
  bool      _isInitialized   = false;
  String?   _errorMessage;

  UserModel? get user          => _user;
  String?    get token         => _token;
  bool       get isLoading     => _isLoading;
  bool       get isInitialized => _isInitialized;
  bool       get isAuthenticated => _user != null && _token != null;
  String?    get errorMessage  => _errorMessage;

  final ApiService _api = ApiService();

  /// Uygulama başlarken kaydedilmiş tokeni kontrol et
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    if (token != null) {
      _token = token;
      try {
        _user = await _api.getMe();
      } catch (_) {
        // Token geçersiz — temizle
        await _clearSession(prefs);
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final data = await _api.login(email, password);
      await _saveSession(data);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String gender,
    required String country,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final data = await _api.register(
        name: name, email: email, password: password,
        gender: gender, country: country,
      );
      await _saveSession(data);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    notifyListeners();
  }

  void updateUser(UserModel updated) {
    _user = updated;
    notifyListeners();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    _token = data['token'] as String;
    _user  = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await prefs.setString(AppConstants.tokenKey, _token!);
    await prefs.setString(AppConstants.userKey, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    _token = null;
    _user  = null;
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] != null) return data['message'];
      if (data is Map && data['errors'] != null) {
        final errors = data['errors'] as Map;
        return errors.values.first.first.toString();
      }
    } catch (_) {}
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
