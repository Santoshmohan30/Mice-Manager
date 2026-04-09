import 'package:flutter/material.dart';

import '../application/services/authentication_service.dart';
import '../application/services/breeding_service.dart';
import '../application/services/calendar_task_service.dart';
import '../application/services/food_restriction_service.dart';
import '../application/services/mouse_service.dart';
import '../application/services/ocr_history_service.dart';
import '../application/services/ocr_parser_service.dart';
import '../application/services/procedure_service.dart';
import '../application/services/sync_service.dart';
import '../infrastructure/database/local_database.dart';
import '../infrastructure/ocr/android_mlkit_ocr_adapter.dart';
import '../infrastructure/repositories/sqlite_breeding_repository.dart';
import '../infrastructure/repositories/sqlite_calendar_task_repository.dart';
import '../infrastructure/repositories/sqlite_food_restriction_repository.dart';
import '../infrastructure/repositories/sqlite_mouse_repository.dart';
import '../infrastructure/repositories/sqlite_ocr_document_repository.dart';
import '../infrastructure/repositories/sqlite_procedure_repository.dart';
import '../infrastructure/repositories/sqlite_sync_repository.dart';
import '../infrastructure/repositories/sqlite_user_repository.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/state/auth_controller.dart';
import '../presentation/state/breeding_controller.dart';
import '../presentation/state/calendar_task_controller.dart';
import '../presentation/state/food_restriction_controller.dart';
import '../presentation/state/mice_controller.dart';
import '../presentation/state/ocr_history_controller.dart';
import '../presentation/state/procedure_controller.dart';
import '../presentation/state/sync_controller.dart';
import '../application/services/authorization_service.dart';

class MiceManagerApp extends StatefulWidget {
  const MiceManagerApp({super.key});

  @override
  State<MiceManagerApp> createState() => _MiceManagerAppState();
}

class _MiceManagerAppState extends State<MiceManagerApp> {
  late final AuthController _authController;
  late final MiceController _miceController;
  late final BreedingController _breedingController;
  late final CalendarTaskController _calendarTaskController;
  late final ProcedureController _procedureController;
  late final OCRHistoryController _ocrHistoryController;
  late final SyncController _syncController;
  late final FoodRestrictionController _foodRestrictionController;
  late final AndroidMlKitOCRAdapter _ocrAdapter;
  late final OCRParserService _ocrParserService;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    final localDatabase = LocalDatabase();
    final userRepository = SqliteUserRepository(localDatabase);
    final authenticationService =
        AuthenticationService(userRepository, const AuthorizationService());
    final ocrHistoryService =
        OCRHistoryService(SqliteOCRDocumentRepository(localDatabase));
    final mouseRepository = SqliteMouseRepository(localDatabase);
    final breedingRepository = SqliteBreedingRepository(localDatabase);
    final procedureRepository = SqliteProcedureRepository(localDatabase);
    final ocrRepository = SqliteOCRDocumentRepository(localDatabase);
    final syncService = SyncService(
      SqliteSyncRepository(localDatabase),
      mouseRepository,
      breedingRepository,
      procedureRepository,
      ocrRepository,
    );
    _ocrAdapter = AndroidMlKitOCRAdapter();
    _ocrParserService = const OCRParserService();
    _authController = AuthController(authenticationService);
    _miceController = MiceController(MouseService(mouseRepository));
    _breedingController =
        BreedingController(BreedingService(breedingRepository));
    _calendarTaskController = CalendarTaskController(
      CalendarTaskService(SqliteCalendarTaskRepository(localDatabase)),
    );
    _procedureController =
        ProcedureController(ProcedureService(procedureRepository));
    _ocrHistoryController = OCRHistoryController(ocrHistoryService);
    _syncController = SyncController(syncService);
    _foodRestrictionController = FoodRestrictionController(
      FoodRestrictionService(SqliteFoodRestrictionRepository(localDatabase)),
    );
    syncService.registerInboundSyncListener(() async {
      await Future.wait([
        _miceController.load(),
        _breedingController.load(),
        _procedureController.load(),
        _ocrHistoryController.load(),
        _syncController.load(),
        _foodRestrictionController.load(),
      ]);
      await _calendarTaskController.syncFromBreedings(
        _breedingController.items,
        _miceController.allMice,
      );
    });
    _initialization = Future.wait([
      _authController.initialize(),
      _miceController.load(),
      _breedingController.load(),
      _procedureController.load(),
      _ocrHistoryController.load(),
      _syncController.load(),
      _foodRestrictionController.load(),
    ]).then((_) {
      return _calendarTaskController.syncFromBreedings(
        _breedingController.items,
        _miceController.allMice,
      );
    });
  }

  @override
  void dispose() {
    _ocrAdapter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mice Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.62),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.45),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 0.1, height: 0.1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.52),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE6FFFB),
              Color(0xFFF7F4EA),
              Color(0xFFE8F0FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: AnimatedBuilder(
        animation: _authController,
        builder: (context, _) => FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to initialize local storage: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            if (!_authController.isAuthenticated) {
              return LoginScreen(controller: _authController);
            }

            return HomeScreen(
              authController: _authController,
              controller: _miceController,
              breedingController: _breedingController,
              calendarTaskController: _calendarTaskController,
              procedureController: _procedureController,
              ocrHistoryController: _ocrHistoryController,
              syncController: _syncController,
              foodRestrictionController: _foodRestrictionController,
              ocrAdapter: _ocrAdapter,
              ocrParserService: _ocrParserService,
            );
          },
        ),
      ),
    );
  }
}
