import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/config/api_config.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/legal_terms_sheet.dart';

/// M01 Inicio de Sesión + M02 Recuperar Contraseña con aceptación obligatoria
/// de Términos y Condiciones y Política de Privacidad.
class LoginScreen extends StatefulWidget {
  final AppState appState;

  const LoginScreen({super.key, required this.appState});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@mirestaurante.pe');
  final _passCtrl = TextEditingController(text: 'password123');
  bool _obscure = true;
  late bool _acceptedTerms;
  String? _error;

  @override
  void initState() {
    super.initState();
    _acceptedTerms = widget.appState.termsAccepted;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() => _error = null);
    final res = await widget.appState.login(
      _emailCtrl.text,
      _passCtrl.text,
      acceptedTerms: _acceptedTerms,
    );
    if (!res.success && mounted) {
      setState(() => _error = res.message ?? 'No se pudo iniciar sesión');
    }
  }

  Future<void> _submitDemoLogin() async {
    setState(() => _error = null);
    _emailCtrl.text = 'admin@mirestaurante.pe';
    _passCtrl.text = 'password123';

    if (!_acceptedTerms) {
      final accepted = await LegalTermsSheet.show(
        context,
        language: widget.appState.language,
      );
      if (accepted != true || !mounted) return;
      setState(() => _acceptedTerms = true);
    }

    final res = await widget.appState.loginDemo(acceptedTerms: true);
    if (!res.success && mounted) {
      setState(() => _error = res.message ?? 'No se pudo iniciar sesión');
    }
  }

  Future<void> _openTermsSheet() async {
    final accepted = await LegalTermsSheet.show(
      context,
      language: widget.appState.language,
    );
    if (accepted == true && mounted) {
      setState(() {
        _acceptedTerms = true;
        _error = null;
      });
    }
  }

  void _openForgotPasswordDialog() {
    final ctrl = TextEditingController(text: _emailCtrl.text);
    final s = widget.appState.strings;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String? statusMsg;
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.isEs ? 'Recuperar contraseña' : 'Reset password',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.isEs
                        ? 'Ingresa tu correo operativo y te enviaremos un enlace de restablecimiento.'
                        : 'Enter your operator email to receive a reset link.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: s.emailLabel),
                  ),
                  if (statusMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      statusMsg!,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.okStrong),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () async {
                            setModalState(() => loading = true);
                            final r =
                                await widget.appState.forgotPassword(ctrl.text);
                            setModalState(() {
                              loading = false;
                              statusMsg = r.message ?? 'Enviado.';
                            });
                          },
                    child: Text(
                      loading
                          ? (s.isEs ? 'Enviando...' : 'Sending...')
                          : (s.isEs ? 'Enviar instrucciones' : 'Send instructions'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.appState.strings;
    final busy = widget.appState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgAlt,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/brand/logo-full.png',
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.thermostat_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Cold2Hot',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            s.loginTitle,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(s.loginSub, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 20),
                          TextField(
                            key: const Key('login_email_field'),
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: s.emailLabel,
                              prefixIcon: const Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('login_password_field'),
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: s.passwordLabel,
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: TextButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                child: Text(
                                  _obscure ? s.showPwd : s.hidePwd,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openForgotPasswordDialog,
                              child: Text(
                                s.forgotPassword,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _acceptedTerms
                                    ? AppColors.ok.withValues(alpha: 0.45)
                                    : AppColors.line,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  key: const Key('terms_checkbox'),
                                  value: _acceptedTerms,
                                  activeColor: AppColors.ink,
                                  onChanged: (v) => setState(() {
                                    _acceptedTerms = v ?? false;
                                    if (_acceptedTerms) _error = null;
                                  }),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text.rich(
                                      TextSpan(
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(height: 1.4),
                                        children: [
                                          TextSpan(text: s.termsPrefix),
                                          TextSpan(
                                            text: s.termsLink,
                                            style: const TextStyle(
                                              color: AppColors.ink,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = _openTermsSheet,
                                          ),
                                          TextSpan(text: s.termsMiddle),
                                          TextSpan(
                                            text: s.privacyLink,
                                            style: const TextStyle(
                                              color: AppColors.ink,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = _openTermsSheet,
                                          ),
                                          const TextSpan(text: ' (GPS & BLE IoT).'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.dangerStrong,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.dangerStrong,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            key: const Key('login_submit_btn'),
                            onPressed: busy ? null : _submitLogin,
                            child: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(s.loginBtn),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const Key('login_demo_btn'),
                            onPressed: busy ? null : _submitDemoLogin,
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: Text(s.loginDemoBtn),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ServerChip(
                        label: 'Render Cloud',
                        selected: widget.appState.baseUrl == ApiConfig.renderUrl,
                        onTap: () =>
                            widget.appState.updateBaseUrl(ApiConfig.renderUrl),
                      ),
                      _ServerChip(
                        label: 'Emulador (10.0.2.2)',
                        selected: widget.appState.baseUrl ==
                            ApiConfig.androidEmulatorUrl,
                        onTap: () => widget.appState
                            .updateBaseUrl(ApiConfig.androidEmulatorUrl),
                      ),
                      _ServerChip(
                        label: 'Localhost',
                        selected:
                            widget.appState.baseUrl == ApiConfig.webLocalUrl,
                        onTap: () => widget.appState
                            .updateBaseUrl(ApiConfig.webLocalUrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: InkWell(
                      onTap: widget.appState.refreshBackendHealth,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.appState.backendOnline
                                    ? AppColors.ok
                                    : AppColors.warn,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.appState.backendOnline
                                    ? 'Backend en línea · Verificar'
                                    : 'Modo demo / Offline · Reintentar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ServerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.bg,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: AppColors.line),
      shape: const StadiumBorder(),
    );
  }
}
