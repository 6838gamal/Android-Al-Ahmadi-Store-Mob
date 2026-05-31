import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../pages/staff_shell.dart';

final _staffInventoryProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/inventory', queryParameters: {'limit': 100});
  return res.data['items'] ?? res.data ?? [];
});

class StaffInventoryPage extends ConsumerStatefulWidget {
  const StaffInventoryPage({super.key});

  @override
  ConsumerState<StaffInventoryPage> createState() => _StaffInventoryPageState();
}

class _StaffInventoryPageState extends ConsumerState<StaffInventoryPage> {
  String _statusFilter = '';

  static const _statusLabels = {
    '': 'الكل',
    'available': 'متوفر',
    'reserved': 'محجوز',
    'sold': 'مباع',
  };

  static const _gradeColors = {
    'A+': Color(0xFF22C55E),
    'A': Color(0xFF3B82F6),
    'B': Color(0xFFF59E0B),
    'C': Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(_staffInventoryProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => StaffShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('المخزون',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(_staffInventoryProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: inventoryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text('حدث خطأ: $e',
                        style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_staffInventoryProvider),
                      child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),
              data: (items) {
                final filtered = _statusFilter.isEmpty
                    ? items
                    : items.where((o) => o['status'] == _statusFilter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 56),
                        const SizedBox(height: 12),
                        const Text('لا توجد عناصر في المخزون',
                            style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _InventoryCard(
                    item: filtered[i],
                    gradeColors: _gradeColors,
                    onMarkSold: (id) => _updateItemStatus(id, 'sold'),
                    onReturnToStock: (id) => _updateItemStatus(id, 'available'),
                  ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.05, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 48,
      color: AppColors.darkSurface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: _statusLabels.entries.map((e) {
          final sel = _statusFilter == e.key;
          return GestureDetector(
            onTap: () => setState(() => _statusFilter = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.primary : AppColors.darkBorder),
              ),
              child: Text(e.value,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _updateItemStatus(int itemId, String newStatus) async {
    try {
      final api = ref.read(apiClientProvider);
      if (newStatus == 'sold') {
        await api.post('/inventory/$itemId/sell');
      } else {
        await api.post('/inventory/$itemId/return-to-stock');
      }
      ref.invalidate(_staffInventoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'sold' ? 'تم تسجيل الشاشة كمباعة' : 'تم إعادة الشاشة للمخزون',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحديث: $e', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _InventoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, Color> gradeColors;
  final void Function(int) onMarkSold;
  final void Function(int) onReturnToStock;

  const _InventoryCard({
    required this.item,
    required this.gradeColors,
    required this.onMarkSold,
    required this.onReturnToStock,
  });

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? 'available';
    final grade = item['grade'] as String? ?? '';
    final gradeColor = gradeColors[grade] ?? AppColors.textMuted;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'available':
        statusColor = const Color(0xFF22C55E);
        statusLabel = 'متوفر';
        break;
      case 'reserved':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'محجوز';
        break;
      case 'sold':
        statusColor = const Color(0xFF6B7280);
        statusLabel = 'مباع';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusLabel = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['model'] ?? item['category'] ?? 'عنصر مخزون',
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                      if (item['serial_number'] != null)
                        Text('S/N: ${item['serial_number']}',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (grade.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: gradeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gradeColor.withOpacity(0.4)),
                    ),
                    child: Text('درجة $grade',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: gradeColor)),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            if (item['category'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(item['category'] ?? '',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
            // Action buttons
            if (status == 'available') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onMarkSold(item['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6B7280)),
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sell_outlined, size: 16),
                  label: const Text('تسجيل كمباعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else if (status == 'sold') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onReturnToStock(item['id']),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF22C55E).withOpacity(0.6)),
                    foregroundColor: const Color(0xFF22C55E),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.replay_outlined, size: 16),
                  label: const Text('إعادة للمخزون', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
