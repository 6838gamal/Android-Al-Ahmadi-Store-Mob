class AppConstants {
  static const String appName = 'أندرويد الأحمدي';
  static const String appNameEn = 'Android Al-Ahmady';
  static const String appSubtitle = 'شاشات وصيانة الهواتف';
  static const String ownerName = 'أكرم الأحمدي';
  static const String shopPhone = '770887247';
  static const String shopWhatsApp = '770887247';
  static const String shopAddress = 'صنعاء، جولة مأرب، جوار مدرسة حسان بن ثابت';
  static const String shopEmail = 'akrm6214@mail.com';
  static const String shopBio = 'متخصصون في بيع وصيانة الجوالات وقطع الغيار بأعلى جودة وأفضل سعر';
  static const Map<String, String> workingHours = {
    'السبت - الأربعاء': '10:00 ص - 10:00 م',
    'الخميس': '10:00 ص - 11:00 م',
    'الجمعة': '4:00 م - 11:00 م',
  };

  // API base URL — for mobile builds use the Render.com deployment
  // For Flutter Web the ApiClient overrides this with Uri.base.origin
  static const String baseUrl = 'https://android-al-ahmadi-store-api.onrender.com';

  static const String apiVersion = '/api';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String onboardingKey = 'onboarding_done';

  // Order statuses
  static const Map<String, String> orderStatusAr = {
    'received': 'تم استلام الطلب',
    'reviewing': 'جاري مراجعة الطلب',
    'confirmed': 'تم تأكيد الطلب',
    'preparing': 'جاري التجهيز',
    'shipped': 'تم الشحن',
    'on_the_way': 'الطلب في الطريق',
    'delivered': 'تم التسليم',
    'cancelled': 'ملغي',
  };

  static const Map<String, String> maintenanceStatusAr = {
    'received': 'تم استلام الجهاز',
    'inspecting': 'تحت الفحص',
    'repairing': 'جاري الإصلاح',
    'waiting_part': 'بانتظار قطعة',
    'repaired': 'تم الإصلاح',
    'ready': 'جاهز للاستلام',
    'delivered': 'تم التسليم',
  };

  static const Map<String, String> categoryAr = {
    'screen': 'شاشات',
    'battery': 'بطاريات',
    'camera': 'كاميرات',
    'speaker': 'سماعات',
    'charger': 'شواحن',
    'device': 'أجهزة',
    'spare_part': 'قطع غيار',
    'other': 'أخرى',
  };

  static const Map<String, String> productStatusAr = {
    'available': 'متوفر',
    'reserved': 'محجوز',
    'sold': 'تم البيع',
    'unavailable': 'غير متوفر',
  };
}
