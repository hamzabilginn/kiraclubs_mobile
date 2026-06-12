import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../config/constants.dart';
import '../services/pusher_service.dart';

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
    print("AUTH_PROVIDER: init() starting...");
    final prefs = await SharedPreferences.getInstance();
    print("AUTH_PROVIDER: SharedPreferences instance obtained");
    final token = prefs.getString(AppConstants.tokenKey);
    print("AUTH_PROVIDER: Token from prefs: $token");

    if (token != null) {
      _token = token;
      try {
        print("AUTH_PROVIDER: Fetching user profile...");
        _user = await _api.getMe();
        print("AUTH_PROVIDER: User profile fetched successfully: ${_user?.name}");
        PusherService().init(token: token);
        print("AUTH_PROVIDER: Pusher initialized");
        try {
          OneSignal.login(_user!.id.toString());
        } catch (e) {
          print("OneSignal login error on startup: $e");
        }
      } catch (e, stack) {
        print("AUTH_PROVIDER: Error fetching user profile: $e");
        print(stack);
        // Token geçersiz — temizle
        await _clearSession(prefs);
      }
    }

    _isInitialized = true;
    notifyListeners();
    print("AUTH_PROVIDER: init() completed");
  }

  Future<void> loadUser() async {
    try {
      _user = await _api.getMe();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final data = await _api.login(email, password);
      await _saveSession(data);
      _setLoading(false);
      return true;
    } catch (e, stack) {
      print("LOGIN ERROR: $e");
      print(stack);
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
    } catch (e, stack) {
      print("REGISTER ERROR: $e");
      print(stack);
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
    PusherService().init(token: _token!);
    try {
      OneSignal.login(_user!.id.toString());
    } catch (e) {
      print("OneSignal login error: $e");
    }
    notifyListeners();
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    _token = null;
    _user  = null;
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    PusherService().disconnect();
    try {
      OneSignal.logout();
    } catch (e) {
      print("OneSignal logout error: $e");
    }
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
    // Geçici debug: gerçek hata mesajını göster
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
