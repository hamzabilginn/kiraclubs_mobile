import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';

class PusherEvent {
  final String eventName;
  final String channelName;
  final dynamic data;
  final String? userId;

  PusherEvent({
    required this.eventName,
    required this.channelName,
    this.data,
    this.userId,
  });
}

class PusherService {
  static final PusherService _instance = PusherService._internal();
  factory PusherService() => _instance;
  PusherService._internal();

  PusherChannelsClient? _client;
  bool _isConnected = false;
  String? _token;

  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, dynamic> _channels = {}; 

  bool get isConnected => _isConnected;

  Future<void> init({required String token}) async {
    if (_isConnected) return;
    _token = token;

    debugPrint("Initializing PusherService with token...");

    final options = PusherChannelsOptions.fromHost(
      scheme: 'wss',
      host: 'www.kiraclubs.com',
      key: 'zv5usg45t22pckyq1ex0',
      port: 443,
    );

    _client = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (exception, trace, refresh) async {
        debugPrint("Pusher Connection Error: $exception");
        refresh();
      },
    );

    _client!.lifecycleStream.listen((state) {
      debugPrint("Pusher Connection State: $state");
      _isConnected = (state == PusherChannelsClientLifeCycleState.establishedConnection);
    });

    _client!.connect();
  }

  Future<void> disconnect() async {
    debugPrint("Disconnecting PusherService...");
    for (var sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _channels.clear();
    await _client?.disconnect();
    _client = null;
    _isConnected = false;
  }

  Future<void> subscribe(String channelName, Function(PusherEvent) onEvent) async {
    if (_client == null) {
      debugPrint("Pusher Client is null, cannot subscribe.");
      return;
    }
    
    await unsubscribe(channelName);

    debugPrint("Subscribing to channel: $channelName");

    if (channelName.startsWith('presence-')) {
      final channel = _client!.presenceChannel(
        channelName,
        authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPresenceChannel(
          authorizationEndpoint: Uri.parse('https://www.kiraclubs.com/api/broadcasting/auth'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
          },
        ),
      );

      _channels[channelName] = channel;
      channel.subscribe();
    } else if (channelName.startsWith('private-')) {
      final channel = _client!.privateChannel(
        channelName,
        authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
          authorizationEndpoint: Uri.parse('https://www.kiraclubs.com/api/broadcasting/auth'),
          headers: {
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
          },
        ),
      );
      
      _channels[channelName] = channel;
      channel.subscribe();
    } else {
      final channel = _client!.publicChannel(channelName);
      _channels[channelName] = channel;
      channel.subscribe();
    }

    // Listen to client event stream and filter events for this channel
    final subscription = _client!.eventStream.listen((event) {
      if (event.channelName == channelName) {
        debugPrint("Event received on channel $channelName: ${event.name}");
        
        dynamic decodedData = event.data;
        if (event.data is String) {
          try {
            decodedData = jsonDecode(event.data);
          } catch (_) {}
        }

        onEvent(PusherEvent(
          eventName: event.name,
          channelName: event.channelName ?? channelName,
          data: decodedData,
          userId: event.userId,
        ));
      }
    });

    _subscriptions[channelName] = subscription;
  }

  Future<void> unsubscribe(String channelName) async {
    debugPrint("Unsubscribing from channel: $channelName");
    final sub = _subscriptions.remove(channelName);
    if (sub != null) {
      await sub.cancel();
    }
    _channels.remove(channelName);
  }
}
