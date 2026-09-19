import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/ref_db.dart';
import 'data/user_db.dart';
import 'services/platform_services.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'ui/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  final state = AppState(ref: RefDb(), user: UserDb(), tts: TtsService(), reminder: ReminderService());
  runApp(ChangeNotifierProvider.value(value: state, child: const HocTiengTrungApp()));
  state.load();
}

class HocTiengTrungApp extends StatelessWidget {
  const HocTiengTrungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Học tiếng Trung',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.ready) return const AppShell();
    return Scaffold(
      backgroundColor: C.pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('学', locale: const Locale('zh', 'CN'), style: const TextStyle(fontSize: 64, color: C.primary)),
            const SizedBox(height: 12),
            Text('Học tiếng Trung', style: ts(20, w: w700)),
            const SizedBox(height: 16),
            if (s.loadError == null) ...[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: C.primary),
              ),
              const SizedBox(height: 10),
              Text('Đang chuẩn bị dữ liệu từ điển…', style: ts(12, c: C.ink500)),
            ] else
              Text('Không mở được dữ liệu:\n${s.loadError}',
                  textAlign: TextAlign.center, style: ts(12, c: C.red, h: 1.5)),
          ]),
        ),
      ),
    );
  }
}
