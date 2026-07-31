import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus status = AuthStatus.unknown;
  User? firebaseUser;
  UserModel? userProfile;
  String? errorMessage;

  late final StreamSubscription<User?> _authSub;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService() {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  bool get isOrganizer => userProfile?.isOrganizer ?? false;

  Future<void> _onAuthChanged(User? user) async {
    firebaseUser = user;
    if (user == null) {
      userProfile = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    userProfile = await _authService.fetchUserProfile(user.uid);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? club,
  }) async {
    errorMessage = null;
    try {
      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        role: role,
        club: club,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? 'Sign up failed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    errorMessage = null;
    try {
      await _authService.signIn(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? 'Sign in failed.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
