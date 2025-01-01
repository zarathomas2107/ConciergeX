import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

class DeepLinkHandler {
  static Future<void> initialize(
    GlobalKey<ScaffoldMessengerState> scaffoldKey,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    try {
      final appLinks = AppLinks();
      
      // Handle incoming links when app is running
      appLinks.uriLinkStream.listen((uri) async {
        await _handleDeepLink(uri, scaffoldKey, navigatorKey);
      });
      
      // Handle initial link if app was launched from link
      final initialUri = await appLinks.getInitialAppLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri, scaffoldKey, navigatorKey);
      }
    } catch (e) {
      debugPrint('Error initializing deep links: $e');
    }
  }

  static Future<void> _handleDeepLink(
    Uri uri,
    GlobalKey<ScaffoldMessengerState> scaffoldKey,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    debugPrint('Handling deep link: $uri');
    
    try {
      if (uri.path.contains('auth-callback')) {
        // Wait for auth state to update
        await Future.delayed(const Duration(seconds: 1));
        
        // Check session
        final currentUser = Supabase.instance.client.auth.currentUser;
        debugPrint('Current user after callback: ${currentUser?.email}');
        
        if (currentUser != null) {
          // Show success message
          scaffoldKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate using navigator key
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          debugPrint('No user found after verification');
          scaffoldKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Please try logging in'),
              backgroundColor: Colors.orange,
            ),
          );
          
          // Navigate to login
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
      scaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 