import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/storage_service.dart';

class UserModel {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
  });

  bool get isCustomer => role == 'customer';
  bool get isStaff => role == 'staff';
  bool get isBranchManager => role == 'branch_manager';
  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        role: json['role'],
        avatarUrl: json['avatar_url'],
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'email': email,
        'phone': phone, 'role': role, 'avatar_url': avatarUrl,
      };
}

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
  });

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  bool get isStaff => user?.isStaff ?? false;
  bool get isBranchManager => user?.isBranchManager ?? false;
  bool get isCustomer => user?.isCustomer ?? false;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isInitialized,
    bool clearUser = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isInitialized: isInitialized ?? this.isInitialized,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final token = await StorageService.getToken();
    final userJson = await StorageService.getUser();
    if (token != null && userJson != null) {
      try {
        final user = UserModel.fromJson(jsonDecode(userJson));
        state = state.copyWith(user: user, isInitialized: true);
        return;
      } catch (_) {}
    }
    state = state.copyWith(isInitialized: true);
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.post('/auth/login', data: {'identifier': identifier, 'password': password});
      final user = UserModel.fromJson(res.data['user']);
      await StorageService.saveToken(res.data['access_token']);
      await StorageService.saveUser(jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'بيانات الدخول غير صحيحة');
      return false;
    }
  }

  Future<bool> register(String name, String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = <String, dynamic>{'name': name, 'password': password};
      if (identifier.contains('@')) {
        data['email'] = identifier;
      } else {
        data['phone'] = identifier;
      }
      final res = await _api.post('/auth/register', data: data);
      final user = UserModel.fromJson(res.data['user']);
      await StorageService.saveToken(res.data['access_token']);
      await StorageService.saveUser(jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل إنشاء الحساب. تحقق من البيانات');
      return false;
    }
  }

  Future<bool> registerWithDetails({
    required String name,
    required String phone,
    String? email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = <String, dynamic>{
        'name': name,
        'phone': phone,
        'password': password,
      };
      if (email != null && email.isNotEmpty) {
        data['email'] = email;
      }
      final res = await _api.post('/auth/register', data: data);
      final user = UserModel.fromJson(res.data['user']);
      await StorageService.saveToken(res.data['access_token']);
      await StorageService.saveUser(jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل إنشاء الحساب. تحقق من البيانات أو جرب رقم جوال آخر');
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.clearToken();
    state = const AuthState(isInitialized: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
