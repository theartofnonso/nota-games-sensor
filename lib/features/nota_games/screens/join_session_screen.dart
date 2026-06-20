import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/features/nota_games/core/player_identity_store.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/features/nota_games/screens/scan_join_screen.dart';
import 'package:trainware/features/nota_games/widgets/nota_screen_scaffold.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class JoinSessionScreen extends StatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _playerNameController = TextEditingController();
  final _sessionIdController = TextEditingController();
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
    _sessionIdController.dispose();
    super.dispose();
  }

  String? _validateName() {
    final name = _playerNameController.text.trim();
    if (name.isEmpty) return 'Enter your name';
    return null;
  }

  Future<void> _join([String? sessionId]) async {
    final nameError = _validateName();
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final id = (sessionId ?? _sessionIdController.text).trim();
    if (id.isEmpty) return;

    setState(() {
      _joining = true;
      _nameError = null;
    });
    await context.read<SessionManager>().joinSession(
          id,
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

    final sessionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanJoinScreen()),
    );
    if (!mounted || sessionId == null) return;

    _sessionIdController.text = sessionId;
    await _join(sessionId);
  }

  InputDecoration _fieldDecoration(ThemeData theme, String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surface.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinError = context.watch<SessionManager>().joinError;

    return NotaScreenScaffold(
      padding: const EdgeInsets.all(24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            'Join session',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your name, then scan the QR or type the session code.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _playerNameController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            style: theme.textTheme.titleLarge,
            decoration: _fieldDecoration(theme, 'Your name'),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _joining ? null : _join(),
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
          OpacityButtonWidgetTwo(
            onPressed: _scanQr,
            isLoading: _joining,
            label: 'Scan QR code',
            showArrowRight: false,
            buttonColor: theme.colors.vibrantAccent,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _sessionIdController,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
            decoration: _fieldDecoration(theme, 'Session ID'),
            onSubmitted: (_) => _joining ? null : _join(),
          ),
          if (joinError != null) ...[
            const SizedBox(height: 12),
            Text(
              joinError,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: error),
            ),
          ],
          const SizedBox(height: 16),
          OpacityButtonWidgetTwo(
            onPressed: _join,
            isLoading: _joining,
            label: 'Join with code',
            showArrowRight: false,
            buttonColor: Colors.white,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
