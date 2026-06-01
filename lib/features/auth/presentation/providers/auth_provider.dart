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
  final double? walletBalance;
  final String? walletCurrency;
  final String? referralCode;
  final int? branchId;

  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.walletBalance,
    this.walletCurrency,
    this.referralCode,
    this.branchId,
  });

  bool get isCustomer => role == 'customer';
  bool get isStaff => role == 'staff';
  bool get isBranchManager => role == 'branch_manager';
  bool get isAdmin => role == 'admin';
  bool get isStaffOrAbove => isStaff || isBranchManager || isAdmin;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        role: json['role'],
        avatarUrl: json['avatar_url'],
        walletBalance: (json['wallet_balance'] as num?)?.toDouble(),
        walletCurrency: json['wallet_currency'],
        referralCode: json['referral_code'],
        branchId: json['branch_id'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'avatar_url': avatarUrl,
        'wallet_balance': walletBalance,
        'wallet_currency': walletCurrency,
        'referral_code': referralCode,
        'branch_id': branchId,
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
  bool get isStaffOrAbove => user?.isStaffOrAbove ?? false;

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
    if (token != null) {
      try {
        // Validate token against the live server — catches stale tokens
        // from old SQLite DB after a PostgreSQL migration.
        final res = await _api.get('/auth/me');
        final user = UserModel.fromJson(res.data);
        await StorageService.saveUser(jsonEncode(user.toJson()));
        state = state.copyWith(user: user, isInitialized: true);
        return;
      } catch (_) {
        // Token invalid / user not found — clear stored credentials
        await StorageService.clearToken();
      }
    }
    state = state.copyWith(isInitialized: true);
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.post('/auth/login',
          data: {'identifier': identifier, 'password': password});
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

  Future<bool> staffLogin(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.post('/auth/staff-login',
          data: {'identifier': identifier, 'password': password});
      final user = UserModel.fromJson(res.data['user']);
      await StorageService.saveToken(res.data['access_token']);
      await StorageService.saveUser(jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'بيانات الدخول غير صحيحة أو الحساب غير مخوّل');
      return false;
    }
  }

  Future<bool> registerWithDetails({
    required String name,
    required String phone,
    String? email,
    required String password,
    String role = 'customer',
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = <String, dynamic>{
        'name': name,
        'phone': phone,
        'password': password,
        'role': 'customer',
      };
      if (email != null && email.isNotEmpty) {
        data['email'] = email;
      }
      if (referralCode != null && referralCode.isNotEmpty) {
        data['referral_code'] = referralCode;
      }
      final res = await _api.post('/auth/register', data: data);
      final user = UserModel.fromJson(res.data['user']);
      await StorageService.saveToken(res.data['access_token']);
      await StorageService.saveUser(jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: 'فشل إنشاء الحساب. تحقق من البيانات أو جرب رقم جوال آخر');
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.clearToken();
    state = const AuthState(isInitialized: true);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (currentPassword != null) data['current_password'] = currentPassword;
      if (newPassword != null) data['new_password'] = newPassword;

      final res = await _api.put('/auth/profile', data: data);
      final updatedUser = UserModel.fromJson(res.data);
      await StorageService.saveUser(jsonEncode(updatedUser.toJson()));
      state = state.copyWith(user: updatedUser);
      return {'success': true};
    } catch (e) {
      String msg = 'فشل تحديث البيانات';
      try {
        final err = (e as dynamic).response?.data;
        if (err is Map && err['detail'] != null) msg = err['detail'];
      } catch (_) {}
      return {'success': false, 'error': msg};
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
