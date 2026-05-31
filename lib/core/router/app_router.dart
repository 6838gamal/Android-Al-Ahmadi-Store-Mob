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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      // ── Auth / Onboarding ────────────────────────────────────────────
      GoRoute(path: '/splash',     builder: (ctx, state) => const SplashPage()),
      GoRoute(path: '/welcome',    builder: (ctx, state) => const WelcomePage()),
      GoRoute(path: '/onboarding', builder: (ctx, state) => const OnboardingPage()),
      GoRoute(path: '/login',      builder: (ctx, state) => const LoginPage()),
      GoRoute(path: '/register',   builder: (ctx, state) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (ctx, state) => const ForgotPasswordPage()),

      // ── Customer Shell ────────────────────────────────────────────────
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

      // ── Staff / Branch-Manager Shell ──────────────────────────────────
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
