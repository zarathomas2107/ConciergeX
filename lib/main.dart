import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/verification_pending_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'utils/deep_link_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load();
  
  debugPrint('Initializing Supabase...');
  
  await Supabase.initialize(
    url: 'https://snxksagtvimkrngjueal.supabase.co',
    anonKey: dotenv.env['SUPABASE_KEY']!,
    debug: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Check initial session
      final session = await Supabase.instance.client.auth.currentSession;
      debugPrint('Initial session: ${session?.user?.email}');

      // Listen for auth state changes
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        debugPrint('Auth state changed: ${data.event}');
        debugPrint('Session: ${data.session?.user?.email}');
        
        if (data.event == AuthChangeEvent.signedIn) {
          debugPrint('User signed in, navigating to home...');
          
          // Ensure we're on the UI thread
          await Future.delayed(Duration.zero);
          
          if (!mounted) return;
          
          // Only show verification message if coming from email verification
          if (data.session?.user?.emailConfirmedAt != null) {
            _scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Email verified successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Force navigation to MainScreen
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        }
      });

      // Handle initial deep link if any
      final initialUri = Uri.base;
      if (initialUri.hasFragment) {
        debugPrint('Initial URI has fragment: ${initialUri.fragment}');
        final params = Uri.splitQueryString(initialUri.fragment);
        if (params.containsKey('access_token')) {
          debugPrint('Found access token in initial URI');
          // The auth state change listener will handle the navigation
        }
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
    } finally {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      navigatorKey: _navigatorKey,
      title: 'ConciergeX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: _initialized
          ? (Supabase.instance.client.auth.currentUser != null
              ? const MainScreen()
              : const LoginScreen())
          : const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
      onGenerateRoute: (settings) {
        debugPrint('Generating route for: ${settings.name}');
        
        // If user is authenticated, force navigation to MainScreen for root route
        if (settings.name == '/' && Supabase.instance.client.auth.currentUser != null) {
          return MaterialPageRoute(builder: (_) => const MainScreen());
        }
        
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case '/signup':
            return MaterialPageRoute(
              builder: (_) => const SignupScreen(),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case '/profile':
            return MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            );
          case '/verification-pending':
            return MaterialPageRoute(
              builder: (_) => const VerificationPendingScreen(),
            );
          case '/verify-email':
            return MaterialPageRoute(
              builder: (_) => const VerifyEmailScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
        }
        return null;
      },
    );
  }
}