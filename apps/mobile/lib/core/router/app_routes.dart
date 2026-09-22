class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const login = '/giris';
  static const noAccess = '/erisim-yok';
  static const platformAdminInfo = '/platform-yonetimi';
  static const waiterHome = '/garson';
  static const waiterTablePattern = '/garson/masa/:tableId';
  static const waiterMenuPattern = '/garson/masa/:tableId/menu';
  static const kitchenHome = '/mutfak';
  static const cashierHome = '/kasa';
  static const businessAdminHome = '/isletme-yoneticisi';

  static String waiterTable(String tableId) => '/garson/masa/$tableId';
  static String waiterMenu(String tableId) => '/garson/masa/$tableId/menu';
}
