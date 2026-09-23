import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/no_access_screen.dart';
import '../features/auth/user_management_screen.dart';
import '../features/management/admin_dashboard_screen.dart';
import '../features/management/excel_export_screen.dart';
import '../features/management/excel_import_screen.dart';
import '../features/management/products_screen.dart';
import '../features/management/settings_screen.dart';
import '../features/management/suppliers_screen.dart';
import '../features/secretary/new_receiving_screen.dart';
import '../features/secretary/secretary_dashboard_screen.dart';
import '../features/secretary/todays_records_screen.dart';
import '../features/sync/sync_coordinator.dart';
import '../features/sync/sync_status_repository.dart';
import '../features/suppliers/supplier_repository.dart';
import '../features/products/product_repository.dart';
import '../features/receiving/delivery_repository.dart';
import '../features/receiving/receiving_service.dart';
import '../features/reports/daily_report_repository.dart';
import '../features/analytics/analytics_repository.dart';
import '../features/analytics/analytics_models.dart';
import '../features/analytics/analytics_report_screen.dart';
import '../features/exports/excel_export_service.dart';
import '../features/imports/excel_import_service.dart';
import '../features/backup/backup_service.dart';
import '../features/suppliers/supplier_statements_screen.dart';
import '../features/assistant/business_assistant_screen.dart';
import '../features/assistant/business_assistant_service.dart';
import 'app_routes.dart';
import 'app_theme.dart';

class AlbncApp extends StatelessWidget {
  AlbncApp({
    required this.productRepository,
    required this.deliveryRepository,
    required this.authRepository,
    SyncStatusRepository? syncStatusRepository,
    this.syncCoordinator,
    DailyReportRepository? reportRepository,
    AnalyticsRepository? analyticsRepository,
    SupplierRepository? repository,
    ReceivingService? receivingService,
    super.key,
    }) : repository = repository ?? SupplierRepository(database: deliveryRepository.database),
         reportRepository = reportRepository ?? DailyReportRepository(deliveryRepository),
        analyticsRepository = analyticsRepository ?? AnalyticsRepository(deliveryRepository.database),
      syncStatusRepository = syncStatusRepository ?? SyncStatusRepository(deliveryRepository.database),
      receivingService = receivingService ?? ReceivingService(database: deliveryRepository.database, supplierRepository: repository ?? SupplierRepository(database: deliveryRepository.database));

  final SupplierRepository repository;
  final ProductRepository productRepository;
  final DeliveryRepository deliveryRepository;
  final DailyReportRepository reportRepository;
  final AnalyticsRepository analyticsRepository;
  final AuthRepository authRepository;
  final SyncStatusRepository syncStatusRepository;
  final SyncCoordinator? syncCoordinator;
  final ReceivingService receivingService;

  Widget _protected(
    Widget screen, {
    UserRole? role,
    AppPermission? permission,
  }) {
    final user = authRepository.currentUser;
    if (user == null ||
        (role != null && user.role != role) ||
        (permission != null && !user.can(permission))) {
      return const NoAccessScreen();
    }
    return screen;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AL-BNC Ventures',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => LoginScreen(authRepository: authRepository),
        AppRoutes.secretaryDashboard: (_) => _protected(
          SecretaryDashboardScreen(statusRepository: syncStatusRepository, onLogout: authRepository.signOut, coordinator: syncCoordinator),
          permission: AppPermission.viewTodaysRecords,
        ),
        AppRoutes.newReceiving: (_) => _protected(
          NewReceivingScreen(
            repository: repository,
            productRepository: productRepository,
            deliveryRepository: deliveryRepository,
            receivingService: receivingService,
          ),
          permission: AppPermission.receiveDeliveries,
        ),
        AppRoutes.todaysRecords: (_) => _protected(
          TodaysRecordsScreen(repository: deliveryRepository, statusRepository: syncStatusRepository, coordinator: syncCoordinator),
          permission: AppPermission.viewTodaysRecords,
        ),
        AppRoutes.adminDashboard: (_) => _protected(
          AdminDashboardScreen(repository: deliveryRepository, analyticsRepository: analyticsRepository, userName: authRepository.currentUser?.displayName ?? 'Admin', onLogout: authRepository.signOut),
          role: UserRole.admin,
        ),
        AppRoutes.suppliers: (_) => _protected(
          SuppliersScreen(repository: repository, deliveryRepository: deliveryRepository, onLogout: authRepository.signOut),
          role: UserRole.admin,
        ),
        AppRoutes.products: (_) => _protected(
          ProductsScreen(repository: productRepository),
          role: UserRole.admin,
        ),
        AppRoutes.reports: (_) => _protected(
              AnalyticsReportScreen(repository: analyticsRepository, productRepository: productRepository, supplierRepository: repository, title: 'Daily Report', initialTrend: AnalyticsTrend.daily, initialFrom: DateTime.now(), initialTo: DateTime.now()),
          role: UserRole.admin,
        ),
        AppRoutes.analytics: (_) => _protected(
          AnalyticsReportScreen(repository: analyticsRepository, productRepository: productRepository, supplierRepository: repository, title: 'Analytics', initialTrend: AnalyticsTrend.monthly),
          role: UserRole.admin,
        ),
        AppRoutes.deliveries: (_) => _protected(
          TodaysRecordsScreen(repository: deliveryRepository, statusRepository: syncStatusRepository, coordinator: syncCoordinator),
          role: UserRole.admin,
        ),
        AppRoutes.monthlyReports: (_) => _protected(
              AnalyticsReportScreen(repository: analyticsRepository, productRepository: productRepository, supplierRepository: repository, title: 'Monthly Report', initialTrend: AnalyticsTrend.monthly, initialFrom: DateTime(DateTime.now().year, DateTime.now().month, 1), initialTo: DateTime.now()),
          role: UserRole.admin,
        ),
        AppRoutes.yearlyReports: (_) => _protected(
          AnalyticsReportScreen(repository: analyticsRepository, productRepository: productRepository, supplierRepository: repository, title: 'Yearly Report', initialTrend: AnalyticsTrend.yearly),
          role: UserRole.admin,
        ),
        AppRoutes.statements: (_) => _protected(
          SupplierStatementsScreen(repository: repository, deliveryRepository: deliveryRepository),
          role: UserRole.admin,
        ),
        AppRoutes.excel: (_) => _protected(
          ExcelExportScreen(service: ExcelExportService(deliveryRepository)),
          role: UserRole.admin,
        ),
        AppRoutes.excelImport: (_) => _protected(
          ExcelImportScreen(
            service: ExcelImportService(
              database: deliveryRepository.database,
              deliveryRepository: deliveryRepository,
              userId: authRepository.currentUser?.id ?? 'unknown',
              receivingService: receivingService,
            ),
          ),
          role: UserRole.admin,
        ),
        AppRoutes.users: (_) => _protected(
          UserManagementScreen(repository: authRepository),
          permission: AppPermission.manageUsers,
        ),
        AppRoutes.settings: (_) => _protected(
          SettingsScreen(backupService: BackupService(deliveryRepository.database)),
          permission: AppPermission.configureSystem,
        ),
        AppRoutes.assistant: (_) => _protected(
          BusinessAssistantScreen(service: BusinessAssistantService(analyticsRepository)),
          role: UserRole.admin,
        ),
      },
    );
  }
}
