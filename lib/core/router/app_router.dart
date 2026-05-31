import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/home/presentation/pages/main_shell.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/products/presentation/pages/product_detail_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/orders/presentation/pages/order_tracking_page.dart';
import '../../features/orders/presentation/pages/create_order_page.dart';
import '../../features/reservations/presentation/pages/reservations_page.dart';
import '../../features/maintenance/presentation/pages/maintenance_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/contact/presentation/pages/contact_page.dart';
import '../../features/staff/presentation/pages/staff_shell.dart';
import '../../features/staff/presentation/pages/staff_home_page.dart';
import '../../features/staff/presentation/pages/staff_orders_page.dart';
import '../../features/staff/presentation/pages/staff_maintenance_page.dart';
import '../../features/staff/presentation/pages/staff_inventory_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final _customerRoutes = {
  '/home', '/products', '/orders', '/reservations',
  '/maintenance', '/notifications', '/profile', '/settings', '/contact',
};

final _staffRoutes = {
  '/staff', '/staff/home', '/staff/orders',
  '/staff/maintenance', '/staff/inventory',
};

/// A ChangeNotifier that listens to [authProvider] and notifies GoRouter
/// to re-evaluate redirects — without recreating the router.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  AuthState get auth => _ref.read(authProvider);
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final auth = notifier.auth;

      if (!auth.isInitialized) return null;

      final isAuth = auth.isAuthenticated;
      final isStaffOrAbove = auth.isStaffOrAbove;
      final isCustomer = auth.isCustomer;

      final isCustomerPath = _customerRoutes.any((r) => path.startsWith(r));
      final isStaffPath = _staffRoutes.any((r) => path.startsWith(r));

      if (!isAuth) {
        if (isCustomerPath || isStaffPath) return '/login';
        return null;
      }

      if (isCustomerPath && isStaffOrAbove) return '/staff';
      if (isStaffPath && isCustomer) return '/products';

      return null;
    },
    routes: [
      // ── Auth / Onboarding ────────────────────────────────────────────
      GoRoute(path: '/splash',     builder: (ctx, state) => const SplashPage()),
      GoRoute(path: '/welcome',    builder: (ctx, state) => const WelcomePage()),
      GoRoute(path: '/onboarding', builder: (ctx, state) => const OnboardingPage()),
      GoRoute(path: '/login',      builder: (ctx, state) => const LoginPage()),
      GoRoute(path: '/register',   builder: (ctx, state) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (ctx, state) => const ForgotPasswordPage()),

      // ── Customer Shell (عميل فقط) ─────────────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home',    builder: (ctx, state) => const ProductsPage()),
          GoRoute(path: '/products', builder: (ctx, state) => const ProductsPage()),
          GoRoute(
            path: '/products/:id',
            builder: (ctx, state) => ProductDetailPage(
              productId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/orders',         builder: (ctx, state) => const OrdersPage()),
          GoRoute(
            path: '/orders/track/:number',
            builder: (ctx, state) => OrderTrackingPage(
              orderNumber: state.pathParameters['number']!,
            ),
          ),
          GoRoute(path: '/orders/create',  builder: (ctx, state) => const CreateOrderPage()),
          GoRoute(path: '/reservations',   builder: (ctx, state) => const ReservationsPage()),
          GoRoute(path: '/maintenance',    builder: (ctx, state) => const MaintenancePage()),
          GoRoute(path: '/notifications',  builder: (ctx, state) => const NotificationsPage()),
          GoRoute(path: '/profile',        builder: (ctx, state) => const ProfilePage()),
          GoRoute(path: '/settings',       builder: (ctx, state) => const SettingsPage()),
          GoRoute(path: '/contact',        builder: (ctx, state) => const ContactPage()),
        ],
      ),

      // ── Staff / Branch-Manager Shell (موظف / مدير فرع فقط) ───────────
      ShellRoute(
        builder: (ctx, state, child) => StaffShell(child: child),
        routes: [
          GoRoute(path: '/staff',            builder: (ctx, state) => const StaffHomePage()),
          GoRoute(path: '/staff/home',       builder: (ctx, state) => const StaffHomePage()),
          GoRoute(path: '/staff/orders',     builder: (ctx, state) => const StaffOrdersPage()),
          GoRoute(path: '/staff/maintenance',builder: (ctx, state) => const StaffMaintenancePage()),
          GoRoute(path: '/staff/inventory',  builder: (ctx, state) => const StaffInventoryPage()),
        ],
      ),
    ],
  );
});
