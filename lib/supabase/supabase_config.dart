import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../config/api_config.dart';

/// Generic Supabase configuration template
class SupabaseConfig {
  // Using the URL from ApiConfig for consistency
  static const String supabaseUrl = ApiConfig.supabaseUrl;
  static const String anonKey = ApiConfig.supabaseAnonKey;

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Supabase already initialized');
      return;
    }

    try {
      // Add timeout and error handling for web platform
      if (kIsWeb) {
        // For web, wrap in try-catch with specific error handling
        try {
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: anonKey,
            debug: kDebugMode,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Supabase initialization timed out');
            },
          );
          _isInitialized = true;
          debugPrint('✅ Supabase initialized successfully on web');
        } catch (e, stackTrace) {
          // Handle null errors from JavaScript (can happen on web)
          String errorMessage;
          try {
            errorMessage = e.toString();
          } catch (_) {
            errorMessage = 'Unknown error (null thrown by JS)';
          }
          debugPrint('❌ Error initializing Supabase on web: $errorMessage');
          debugPrint('Stack trace: $stackTrace');
          // Don't rethrow - allow app to continue without Supabase
          // The app can work in offline mode or with cached data
          _isInitialized = false;
        }
      } else {
        // For mobile platforms
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: anonKey,
          debug: kDebugMode,
        );
        _isInitialized = true;
        debugPrint('✅ Supabase initialized successfully');
      }
    } catch (e, stackTrace) {
      // Handle null errors from JavaScript
      final errorMessage = e.toString();
      debugPrint('❌ Error initializing Supabase: $errorMessage');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
      // Don't rethrow - allow app to continue
    }
  }

  static bool get isInitialized => _isInitialized;

  static SupabaseClient? get client {
    if (!_isInitialized) {
      debugPrint('⚠️ Supabase not initialized. Returning null client.');
      return null;
    }
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('❌ Error accessing Supabase client: $e');
      return null;
    }
  }

  static GoTrueClient? get auth {
    final clientInstance = client;
    if (clientInstance == null) {
      debugPrint('⚠️ Cannot get auth client - Supabase not initialized');
      return null;
    }
    return clientInstance.auth;
  }
}

/// Authentication service - Remove this class if your project doesn't need auth
class SupabaseAuth {
  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    final authClient = SupabaseConfig.auth;
    if (authClient == null) {
      throw Exception('Supabase not initialized. Cannot sign up.');
    }

    try {
      final response = await authClient.signUp(
        email: email,
        password: password,
        data: userData,
      );

      // Optional: Create user profile after successful signup
      if (response.user != null) {
        await _createUserProfile(response.user!, userData);
      }

      return response;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final authClient = SupabaseConfig.auth;
    if (authClient == null) {
      throw Exception('Supabase not initialized. Cannot sign in.');
    }

    try {
      return await authClient.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    final authClient = SupabaseConfig.auth;
    if (authClient == null) {
      debugPrint('⚠️ Supabase not initialized. Cannot sign out.');
      return;
    }

    try {
      await authClient.signOut();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Reset password
  static Future<void> resetPassword(String email) async {
    final authClient = SupabaseConfig.auth;
    if (authClient == null) {
      throw Exception('Supabase not initialized. Cannot reset password.');
    }

    try {
      await authClient.resetPasswordForEmail(email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Get current user
  static User? get currentUser {
    final authClient = SupabaseConfig.auth;
    if (authClient == null) return null;
    return authClient.currentUser;
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Auth state changes stream
  static Stream<AuthState>? get authStateChanges {
    final authClient = SupabaseConfig.auth;
    if (authClient == null) return null;
    return authClient.onAuthStateChange;
  }

  /// Create user profile in database (modify based on your schema)
  static Future<void> _createUserProfile(
    User user,
    Map<String, dynamic>? userData,
  ) async {
    try {
      // Check if profile already exists
      final existingUser = await SupabaseService.selectSingle(
        'users', // Change table name as needed
        filters: {'id': user.id},
      );

      if (existingUser == null) {
        await SupabaseService.insert('users', {
          'id': user.id,
          'email': user.email,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          ...?userData, // Spread additional user data if provided
        });
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      // Don't throw here to avoid breaking the signup flow
    }
  }

  /// Handle authentication errors
  static String _handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Invalid email or password';
        case 'Email not confirmed':
          return 'Please check your email and confirm your account';
        case 'User not found':
          return 'No account found with this email';
        case 'Signup requires a valid password':
          return 'Password must be at least 6 characters';
        case 'Too many requests':
          return 'Too many attempts. Please try again later';
        default:
          return 'Authentication error: ${error.message}';
      }
    } else if (error is PostgrestException) {
      return 'Database error: ${error.message}';
    } else {
      return 'Network error. Please check your connection';
    }
  }
}

/// Generic database service for CRUD operations
class SupabaseService {
  /// Select multiple records from a table
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception('Supabase not initialized. Cannot select from $table.');
    }

    try {
      dynamic query = client.from(table).select(select ?? '*');

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      return await query;
    } catch (e) {
      throw _handleDatabaseError('select', table, e);
    }
  }

  /// Select a single record from a table
  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception('Supabase not initialized. Cannot select from $table.');
    }

    try {
      dynamic query = client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.maybeSingle();
    } catch (e) {
      throw _handleDatabaseError('selectSingle', table, e);
    }
  }

  /// Insert a record into a table
  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception('Supabase not initialized. Cannot insert into $table.');
    }

    try {
      return await client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insert', table, e);
    }
  }

  /// Insert multiple records into a table
  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception('Supabase not initialized. Cannot insert into $table.');
    }

    try {
      return await client.from(table).insert(data).select();
    } catch (e) {
      throw _handleDatabaseError('insertMultiple', table, e);
    }
  }

  /// Update records in a table
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception('Supabase not initialized. Cannot update $table.');
    }

    try {
      dynamic query = client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.select();
    } catch (e) {
      throw _handleDatabaseError('update', table, e);
    }
  }

  /// Delete records from a table
  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception('Supabase not initialized. Cannot delete from $table.');
    }

    try {
      dynamic query = client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;
    } catch (e) {
      throw _handleDatabaseError('delete', table, e);
    }
  }

  /// Get direct table reference for complex queries
  static PostgrestQueryBuilder? from(String table) {
    final client = SupabaseConfig.client;
    if (client == null) {
      debugPrint(
        '⚠️ Supabase not initialized. Cannot get table reference for $table.',
      );
      return null;
    }
    return client.from(table);
  }

  /// Handle database errors
  static String _handleDatabaseError(
    String operation,
    String table,
    dynamic error,
  ) {
    if (error is PostgrestException) {
      return 'Failed to $operation from $table: ${error.message}';
    } else {
      return 'Failed to $operation from $table: ${error.toString()}';
    }
  }
}
