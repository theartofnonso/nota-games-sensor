import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gameware/colors.dart';
import 'package:gameware/features/nota_games/core/nota_fade_route.dart';
import 'package:gameware/features/nota_games/core/player_identity_store.dart';
import 'package:gameware/features/nota_games/managers/session_manager.dart';
import 'package:gameware/features/nota_games/screens/scan_join_screen.dart';
import 'package:gameware/features/nota_games/widgets/nota_screen_scaffold.dart';
import 'package:gameware/utils/theme/color_extensions.dart';

class JoinSessionScreen extends StatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _playerNameController = TextEditingController();
  bool _joining = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final name = await PlayerIdentityStore.loadPlayerName();
    if (!mounted || name == null) return;
    _playerNameController.text = name;
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  String? _validateName() {
    final name = _playerNameController.text.trim();
    if (name.isEmpty) return 'Enter your name';
    return null;
  }

  Future<void> _join(String sessionId) async {
    setState(() {
      _joining = true;
      _nameError = null;
    });
    await context.read<SessionManager>().joinSession(
      sessionId,
      playerName: _playerNameController.text.trim(),
    );
    if (mounted) setState(() => _joining = false);
  }

  Future<void> _scanQr() async {
    final nameError = _validateName();
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final sessionId = await Navigator.of(
      context,
    ).push<String>(notaFadeRoute(const ScanJoinScreen()));
    if (!mounted || sessionId == null) return;

    await _join(sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinError = context.watch<SessionManager>().joinError;

    return NotaScreenScaffold(
      padding: const EdgeInsets.all(24),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Nota Games Sensor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Foun',
                      fontSize: 28,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _playerNameController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                    style: theme.textTheme.titleLarge,
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      filled: true,
                      fillColor: theme.colorScheme.surface.withValues(
                        alpha: 0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  if (_nameError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _nameError!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _JoinSessionButton(
                    onPressed: _joining ? null : _scanQr,
                    isLoading: _joining,
                    accent: theme.colors.vibrantAccent,
                  ),
                  if (joinError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      joinError,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: error),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JoinSessionButton extends StatelessWidget {
  const _JoinSessionButton({
    required this.onPressed,
    required this.isLoading,
    required this.accent,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(
            accent.withValues(alpha: 0.15),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          overlayColor: WidgetStateProperty.all(
            Colors.black.withValues(alpha: 0.3),
          ),
        ),
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
              ] else ...[
                FaIcon(FontAwesomeIcons.qrcode, size: 18, color: accent),
                const SizedBox(width: 10),
                Text(
                  'Join session',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
