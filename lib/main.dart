import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/theme.dart';
import 'data/asset_repository.dart';
import 'data/gemini_service.dart';
import 'data/local_database.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    repo: AssetRepository(),
    db: LocalDatabase.instance,
    gemini: GeminiService(),
  );
  await state.init();
  runApp(ChangeNotifierProvider(create: (_) => state, child: const AtlasApp()));
}

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: state.initError == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('تعذّر فتح البيانات المحلية: ${state.initError}'),
                  ),
          ),
        ),
      );
    }
    return MaterialApp.router(
      title: 'أطلس السوق',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      routerConfig: appRouter,
    );
  }
}
