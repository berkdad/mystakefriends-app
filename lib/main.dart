import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(const MyStakeFriendsApp());
}

class MyStakeFriendsApp extends StatelessWidget {
  const MyStakeFriendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<FCMService>(
          create: (_) => FCMService(),
        ),
      ],
      child: MaterialApp(
        title: 'My Circle',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isTimeout = false;

  @override
  void initState() {
    super.initState();
    print('🔄 AuthWrapper initialized');

    // Add a 3-second timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isTimeout) {
        setState(() {
          _isTimeout = true;
        });
        print('⏱️ Auth check timeout - proceeding to show UI');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        print('🔍 Auth state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, isTimeout: $_isTimeout');

        // If timeout occurs while still waiting, default to login
        if (_isTimeout && snapshot.connectionState == ConnectionState.waiting) {
          print('⚠️ Timeout reached while waiting - showing login screen');
          return const LoginScreen();
        }

        // Show loading spinner only for a short time
        if (snapshot.connectionState == ConnectionState.waiting && !_isTimeout) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle errors by showing login
        if (snapshot.hasError) {
          print('❌ Auth stream error: ${snapshot.error}');
          return const LoginScreen();
        }

        // User is authenticated
        if (snapshot.hasData && snapshot.data != null) {
          print('✅ User authenticated: ${snapshot.data!.uid}');
          return const DashboardScreen();
        }

        // No user - show login
        print('👤 No user - showing login screen');
        return const LoginScreen();
      },
    );
  }
}