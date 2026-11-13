import 'package:material_ui/material_ui.dart';
import 'core/state/app_state.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/permissions/permissions_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Cold2HotOperatorApp());
}

class Cold2HotOperatorApp extends StatefulWidget {
  final AppState? appState;

  const Cold2HotOperatorApp({super.key, this.appState});

  @override
  State<Cold2HotOperatorApp> createState() => _Cold2HotOperatorAppState();
}

class _Cold2HotOperatorAppState extends State<Cold2HotOperatorApp> {
  late final AppState _appState;
  late final bool _ownsState;

  @override
  void initState() {
    super.initState();
    _ownsState = widget.appState == null;
    _appState = widget.appState ?? AppState();
  }

  @override
  void dispose() {
    if (_ownsState) {
      _appState.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        Widget home;
        if (!_appState.isAuthenticated) {
          home = LoginScreen(appState: _appState);
        } else if (!_appState.permissionsGatePassed &&
            !_appState.permissions.allRequiredGranted) {
          home = PermissionsGateScreen(appState: _appState);
        } else {
          home = HomeShell(appState: _appState);
        }

        return MaterialApp(
          title: 'Cold2Hot Operador',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: home,
        );
      },
    );
  }
}
