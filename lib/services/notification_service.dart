import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../screens/call/call_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../config/constants.dart';

class NotificationService {
  static String? pendingUrl;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void init() {
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(AppConstants.oneSignalAppId);
      OneSignal.Notifications.requestPermission(true);

      // Register click listener
      OneSignal.Notifications.addClickListener((event) {
        print("NotificationService: Notification clicked event: ${event.notification.jsonRepresentation()}");
        final data = event.notification.additionalData;
        if (data != null && data['url'] != null) {
          final url = data['url'] as String;
          handleNotificationUrl(url);
        }
      });

      print("NotificationService: OneSignal initialized and click listener registered.");
    } catch (e) {
      print("NotificationService: OneSignal initialization error: $e");
    }
  }

  static Future<void> handleNotificationUrl(String url) async {
    print("NotificationService: Handling notification URL: $url");
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isEmpty) return;

      final context = navigatorKey.currentContext;
      if (context == null) {
        print("NotificationService: Navigator context is null, saving as pending.");
        pendingUrl = url;
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated) {
        print("NotificationService: User is not authenticated, saving as pending.");
        pendingUrl = url;
        return;
      }

      final apiService = ApiService();

      if (segments.length >= 2 && segments[0] == 'call') {
        final callerId = int.tryParse(segments[1]);
        if (callerId != null) {
          print("NotificationService: Navigating to CallScreen for caller ID: $callerId");
          // Fetch caller user profile
          final profileData = await apiService.getUserById(callerId);
          final callerUser = profileData['user'] as UserModel;
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(chatUser: callerUser),
            ),
          );
        }
      } else if (segments.length >= 2 && segments[0] == 'chat') {
        final partnerId = int.tryParse(segments[1]);
        if (partnerId != null) {
          print("NotificationService: Navigating to ChatScreen for partner ID: $partnerId");
          // Fetch partner user profile
          final profileData = await apiService.getUserById(partnerId);
          final partnerUser = profileData['user'] as UserModel;
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(partner: partnerUser),
            ),
          );
        }
      }
    } catch (e) {
      print("NotificationService: Error handling URL navigation: $e");
    }
  }

  static void handlePendingNotification() {
    if (pendingUrl != null) {
      final url = pendingUrl!;
      print("NotificationService: Processing pending notification URL: $url");
      pendingUrl = null;
      handleNotificationUrl(url);
    }
  }
}
