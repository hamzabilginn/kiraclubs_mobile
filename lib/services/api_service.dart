import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept':       'application/json',
        'Content-Type': 'application/json',
      },
    ));

    // Token interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    ));
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email, 'password': password,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String gender,
    required String country,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'name': name, 'email': email, 'password': password,
      'gender': gender, 'country': country,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  Future<UserModel> getMe() async {
    final res = await _dio.get('/profile');
    return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  // ─── Discover ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDiscover({
    int page = 1,
    String? search,
    bool? online,
    bool? hasMedia,
    bool? verified,
    String? country,
    bool? newest,
  }) async {
    final Map<String, dynamic> queryParams = {'page': page};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (online == true) queryParams['online'] = 1;
    if (hasMedia == true) queryParams['has_media'] = 1;
    if (verified == true) queryParams['verified'] = 1;
    if (country != null && country.isNotEmpty) queryParams['country'] = country;
    if (newest == true) queryParams['newest'] = 1;

    final res = await _dio.get('/discover', queryParameters: queryParams);
    
    final list = res.data['profiles'] as List<dynamic>;
    final profiles = list.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
    
    final countries = (res.data['countries'] as List<dynamic>?)
        ?.map((c) => c as Map<String, dynamic>)
        .toList() ?? [];

    return {
      'profiles': profiles,
      'countries': countries,
      'current_page': res.data['current_page'] as int? ?? 1,
      'last_page': res.data['last_page'] as int? ?? 1,
      'next_page_url': res.data['next_page_url'],
    };
  }

  Future<UserModel> getUserById(int userId) async {
    final res = await _dio.get('/user/$userId/profile');
    return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────

  Future<List<ConversationModel>> getInbox() async {
    final res = await _dio.get('/chat/inbox');
    final list = res.data['conversations'] as List<dynamic>;
    return list
        .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getMessages(int userId) async {
    final res = await _dio.get('/chat/$userId');
    final messages = (res.data['messages'] as List<dynamic>)
        .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
        .toList();
    final partner = UserModel.fromJson(res.data['partner'] as Map<String, dynamic>);
    return {'messages': messages, 'partner': partner};
  }

  Future<MessageModel> sendMessage(int userId, String body) async {
    final res = await _dio.post('/chat/$userId', data: {'body': body});
    return MessageModel.fromJson(res.data['message'] as Map<String, dynamic>);
  }

  Future<int> getUnreadCount() async {
    final res = await _dio.get('/chat/unread');
    return res.data['unread_count'] as int? ?? 0;
  }

  // ─── Social ───────────────────────────────────────────────────────────────

  Future<bool> likeUser(int userId) async {
    final res = await _dio.post('/user/$userId/like');
    return res.data['liked'] as bool;
  }

  Future<bool> followUser(int userId) async {
    final res = await _dio.post('/user/$userId/follow');
    return res.data['following'] as bool;
  }

  Future<void> blockUser(int userId) async {
    await _dio.post('/user/$userId/block');
  }

  Future<void> reportUser(int userId, String reason) async {
    await _dio.post('/user/$userId/report', data: {'reason': reason});
  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final res = await _dio.get('/leaderboard');
    return (res.data['leaderboard'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  Future<UserModel> updateProfile({String? name, String? bio, String? country}) async {
    final res = await _dio.put('/profile', data: {
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (country != null) 'country': country,
    });
    return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  Future<String> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final res = await _dio.post('/profile/avatar', data: formData);
    return res.data['avatar_url'] as String;
  }

  Future<Map<String, dynamic>> uploadMedia(String filePath, String type) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'type': type,
    });
    final res = await _dio.post('/profile/media', data: formData);
    return res.data['media'] as Map<String, dynamic>;
  }

  Future<void> deleteMedia(int mediaId) async {
    await _dio.delete('/profile/media/$mediaId');
  }

  Future<List<Map<String, dynamic>>> getVisitors() async {
    final res = await _dio.get('/profile/visitors');
    return (res.data['visitors'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  // ─── Wallet ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWallet() async {
    final res = await _dio.get('/wallet');
    return res.data as Map<String, dynamic>;
  }

  // ─── Call ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initiateCall(int userId) async {
    final res = await _dio.get('/call/$userId');
    return res.data as Map<String, dynamic>;
  }
}
