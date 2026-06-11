import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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

    if (_dio.httpClientAdapter is IOHttpClientAdapter) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }

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

  Future<Map<String, dynamic>> getMeWithTasks() async {
    final res = await _dio.get('/profile');
    return {
      'user': UserModel.fromJson(res.data['user'] as Map<String, dynamic>),
      'daily_tasks': res.data['daily_tasks'] as Map<String, dynamic>? ?? {},
    };
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

  Future<Map<String, dynamic>> getUserById(int userId) async {
    final res = await _dio.get('/user/$userId/profile');
    return {
      'user': UserModel.fromJson(res.data['user'] as Map<String, dynamic>),
      'is_following': res.data['is_following'] as bool? ?? false,
    };
  }

  Future<Map<String, dynamic>> uploadVerificationPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'verification_photo': await MultipartFile.fromFile(filePath, filename: 'verification.jpg'),
    });
    final res = await _dio.post('/profile/verify-upload', data: formData);
    return res.data as Map<String, dynamic>;
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getInbox() async {
    try {
      final res = await _dio.get('/chat/inbox');
      final conversationsList = res.data['conversations'] as List<dynamic>? ?? [];
      final conversations = conversationsList
          .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
          .toList();

      final callsList = res.data['calls'] as List<dynamic>? ?? [];
      final calls = callsList
          .map((c) => CallLogItem.fromJson(c as Map<String, dynamic>))
          .toList();

      return {
        'conversations': conversations,
        'calls': calls,
      };
    } catch (e, stack) {
      print("Error in getInbox API: $e");
      print(stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMessages(int userId) async {
    try {
      final res = await _dio.get('/chat/$userId');
      final messages = (res.data['messages'] as List<dynamic>)
          .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
          .toList();
      final partner = UserModel.fromJson(res.data['partner'] as Map<String, dynamic>);
      return {'messages': messages, 'partner': partner};
    } catch (e, stack) {
      print("Error in getMessages API for user $userId: $e");
      print(stack);
      rethrow;
    }
  }

  Future<MessageModel> sendMessage(int userId, String body) async {
    try {
      final res = await _dio.post('/chat/$userId', data: {'body': body});
      return MessageModel.fromJson(res.data['message'] as Map<String, dynamic>);
    } catch (e, stack) {
      print("Error in sendMessage API for user $userId: $e");
      print(stack);
      rethrow;
    }
  }

  Future<void> markAsRead(int userId) async {
    try {
      await _dio.post('/chat/$userId/read');
    } catch (e, stack) {
      print("Error in markAsRead API for user $userId: $e");
      print(stack);
      rethrow;
    }
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

  Future<Map<String, dynamic>> buyVip(String package) async {
    final res = await _dio.post('/vip/buy', data: {'package': package});
    return res.data as Map<String, dynamic>;
  }

  // ─── Profile ──────────────────────────────────────────────────────────────

  Future<UserModel> updateProfile({String? name, String? bio, String? country, bool? isIncognito}) async {
    final res = await _dio.put('/profile', data: {
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (country != null) 'country': country,
      if (isIncognito != null) 'is_incognito': isIncognito,
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
    final list = (res.data['visitors'] as List<dynamic>? ?? []);
    return list.map((v) {
      final raw = v as Map<String, dynamic>;
      final viewerRaw = raw['viewer'] as Map<String, dynamic>?;
      return {
        'viewer': viewerRaw != null ? UserModel.fromJson(viewerRaw) : null,
        'is_locked': raw['is_locked'] as bool? ?? false,
        'updated_at': raw['updated_at'] as String?,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getLikers() async {
    final res = await _dio.get('/profile/likers');
    final list = (res.data['likers'] as List<dynamic>? ?? []);
    return list.map((l) {
      final raw = l as Map<String, dynamic>;
      final senderRaw = raw['sender'] as Map<String, dynamic>?;
      return {
        'sender': senderRaw != null ? UserModel.fromJson(senderRaw) : null,
        'is_locked': raw['is_locked'] as bool? ?? false,
        'target_label': raw['target_label'] as String? ?? 'Beğendi',
        'created_at': raw['created_at'] as String?,
        'id': raw['id'],
        'type': raw['type'] as String? ?? 'photo',
      };
    }).toList();
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

  // ─── Statuses ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStatuses({int page = 1}) async {
    final res = await _dio.get('/statuses', queryParameters: {'page': page});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createStatus({required String content, String? mediaPath}) async {
    final Map<String, dynamic> data = {'content': content};
    if (mediaPath != null) {
      data['media'] = await MultipartFile.fromFile(mediaPath);
    }
    final res = await _dio.post('/status', data: FormData.fromMap(data));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> likeStatus(int statusId) async {
    final res = await _dio.post('/status/$statusId/like');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteStatus(int statusId) async {
    final res = await _dio.delete('/status/$statusId');
    return res.data as Map<String, dynamic>;
  }

  // ─── Rooms ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getRooms() async {
    final res = await _dio.get('/rooms');
    return res.data['rooms'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createRoom({
    required String name,
    String? description,
    String? category,
    String? coverPath,
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
    };
    if (coverPath != null) {
      data['cover_image'] = await MultipartFile.fromFile(coverPath);
    }
    final res = await _dio.post('/rooms', data: FormData.fromMap(data));
    return res.data as Map<String, dynamic>;
  }

  // ─── Support Tickets ──────────────────────────────────────────────────────

  Future<List<dynamic>> getSupportTickets() async {
    final res = await _dio.get('/support');
    return res.data['tickets'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String title,
    required String message,
  }) async {
    final res = await _dio.post('/support', data: {
      'title': title,
      'message': message,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSupportTicketDetails(int ticketId) async {
    final res = await _dio.get('/support/$ticketId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> replySupportTicket({
    required int ticketId,
    required String message,
  }) async {
    final res = await _dio.post('/support/$ticketId/reply', data: {
      'message': message,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeSupportTicket(int ticketId) async {
    final res = await _dio.post('/support/$ticketId/close');
    return res.data as Map<String, dynamic>;
  }

  // ─── Payout Withdrawals ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String paymentMethod,
    String? iban,
    String? accountName,
    String? bankName,
    String? cryptoAddress,
  }) async {
    final res = await _dio.post('/wallet/withdraw', data: {
      'amount': amount,
      'payment_method': paymentMethod,
      if (iban != null) 'iban': iban,
      if (accountName != null) 'account_name': accountName,
      if (bankName != null) 'bank_name': bankName,
      if (cryptoAddress != null) 'crypto_address': cryptoAddress,
    });
    return res.data as Map<String, dynamic>;
  }

  // ─── Profile Unlocks ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> unlockProfileVisitor(int viewerId) async {
    final res = await _dio.post('/profile/visitors/$viewerId/unlock');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unlockProfileLiker(String type, int likeId) async {
    final res = await _dio.post('/profile/likers/$type/$likeId/unlock');
    return res.data as Map<String, dynamic>;
  }

  // ─── Status Views & Comments ──────────────────────────────────────────────

  Future<void> viewStatus(int statusId) async {
    await _dio.post('/status/$statusId/view');
  }

  Future<List<dynamic>> getStatusViewers(int statusId) async {
    final res = await _dio.get('/status/$statusId/viewers');
    return res.data['viewers'] as List<dynamic>;
  }

  Future<List<dynamic>> getStatusComments(int statusId) async {
    final res = await _dio.get('/status/$statusId/comments');
    return res.data['comments'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> postStatusComment(int statusId, String comment) async {
    final res = await _dio.post('/status/$statusId/comments', data: {
      'comment': comment,
    });
    return res.data as Map<String, dynamic>;
  }

  // ─── Agency Management ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAgencyIndex() async {
    final res = await _dio.get('/agency');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinAgency(String inviteCode) async {
    final res = await _dio.post('/agency/join', data: {
      'invite_code': inviteCode,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> leaveAgency() async {
    final res = await _dio.post('/agency/leave');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeAgencyPublisher(int publisherId) async {
    final res = await _dio.post('/agency/remove-publisher/$publisherId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleAgencyPublisherFreeze(int publisherId) async {
    final res = await _dio.post('/agency/publisher/$publisherId/toggle-freeze');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAgencyPublisherCommission(int publisherId, double commissionRate) async {
    final res = await _dio.post('/agency/publisher/$publisherId/update-commission', data: {
      'commission_rate': commissionRate,
    });
    return res.data as Map<String, dynamic>;
  }

  // ─── Mass Messaging ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendMassMessage(String message) async {
    final res = await _dio.post('/discover/mass-message', data: {
      'message': message,
    });
    return res.data as Map<String, dynamic>;
  }

  // ─── Manual Wallet Deposits ────────────────────────────────────────────────
  
  Future<Map<String, dynamic>> createDepositRequest({
    required double usdtAmount,
    required String paymentMethod,
    String? txid,
    String? senderName,
  }) async {
    final res = await _dio.post('/wallet/deposit', data: {
      'usdt_amount': usdtAmount,
      'payment_method': paymentMethod,
      if (txid != null) 'txid': txid,
      if (senderName != null) 'sender_name': senderName,
    });
    return res.data as Map<String, dynamic>;
  }

  // ─── Voice Room Details & Actions ──────────────────────────────────────────

  Future<Map<String, dynamic>> getRoomDetails(int roomId) async {
    final res = await _dio.get('/rooms/$roomId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> leaveRoom(int roomId) async {
    final res = await _dio.post('/rooms/$roomId/leave');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> inviteToSpeak(int roomId, int userId) async {
    final res = await _dio.post('/rooms/$roomId/invite/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptSpeakInvite(int roomId) async {
    final res = await _dio.post('/rooms/$roomId/accept');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> demoteSpeaker(int roomId, int userId) async {
    final res = await _dio.post('/rooms/$roomId/demote/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> kickUser(int roomId, int userId) async {
    final res = await _dio.post('/rooms/$roomId/kick/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> roomHeartbeat(int roomId) async {
    final res = await _dio.post('/rooms/$roomId/heartbeat');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> raiseHand(int roomId) async {
    final res = await _dio.post('/rooms/$roomId/raise-hand');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> lowerHand(int roomId, int userId) async {
    final res = await _dio.post('/rooms/$roomId/lower-hand/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleRoomLock(int roomId) async {
    final res = await _dio.post('/rooms/$roomId/toggle-lock');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendRoomEmoji(int roomId, String emoji) async {
    final res = await _dio.post('/rooms/$roomId/emoji', data: {'emoji': emoji});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRoomMessages(int roomId) async {
    final res = await _dio.get('/rooms/$roomId/messages');
    return res.data['messages'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendRoomMessage(int roomId, String message) async {
    final res = await _dio.post('/rooms/$roomId/messages', data: {'message': message});
    return res.data as Map<String, dynamic>;
  }
}
