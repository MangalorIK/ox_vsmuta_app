import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'notification_service.dart';
import 'messages_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    // 1. Запрашиваем разрешение на уведомления (важно для Android 13+ и iOS)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('🔔 Статус разрешения: ${settings.authorizationStatus}');

    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    // 2. Подписываемся/отписываемся от топика (с обработкой ошибок)
    try {
      if (_notificationsEnabled) {
        await FirebaseMessaging.instance.subscribeToTopic('locations');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('locations');
      }
    } catch (e) {
      print('❌ Ошибка подписки на топик: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    try {
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic('locations');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('locations');
      }
    } catch (e) {
      print('Ошибка подписки: $e');
      setState(() => _notificationsEnabled = !value);
      await prefs.setBool('notifications_enabled', !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.green),
      home: MessagesScreen(
        notificationsEnabled: _notificationsEnabled,
        onNotificationsChanged: _toggleNotifications,
      ),
    );
  }
}
