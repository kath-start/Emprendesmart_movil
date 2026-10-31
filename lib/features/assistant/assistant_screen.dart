import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../plans/plans_screen.dart';
import 'assistant_service.dart';

const _greeting =
    '¡Hola! Soy tu asistente de EmprendeSmart. Pregúntame sobre tus ventas, tu inventario o tus productos.';

/// Preguntas de ejemplo para quien no sabe por dónde empezar.
const _suggestions = [
  '¿Cuánto vendí esta semana?',
  '¿Qué productos tienen stock bajo?',
  '¿Cuál es mi producto más vendido?',
  '¿Qué me recomiendas para vender más?',
];

/// Saludo y preguntas cuando el negocio todavía es una idea (aún no vende).
const _ideaGreeting =
    '¡Hola! Soy tu asistente de EmprendeSmart. Te ayudo a validar tu idea y a preparar el lanzamiento de tu negocio. ¿Por dónde empezamos?';

const _ideaSuggestions = [
  '¿Es buena mi idea? Ayúdame a validarla',
  'Dame un plan para mi primer mes',
  'Sugiéreme nombres para mi negocio',
  '¿Cómo consigo mis primeros clientes?',
  '¿Qué productos debería vender primero?',
];

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime sentAt;

  _ChatMessage({required this.role, required this.content}) : sentAt = DateTime.now();
}

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minutes = time.minute.toString().padLeft(2, '0');
  return '$hour:$minutes ${time.hour < 12 ? 'a. m.' : 'p. m.'}';
}

class AssistantScreen extends StatefulWidget {
  final String businessId;

  /// El negocio está en etapa IDEA: el asistente ayuda a validar y lanzar, no a analizar ventas.
  final bool ideaMode;

  const AssistantScreen({super.key, required this.businessId, this.ideaMode = false});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final AssistantService _assistantService;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final List<_ChatMessage> _messages = [_ChatMessage(role: 'assistant', content: _greetingText)];

  String get _greetingText => widget.ideaMode ? _ideaGreeting : _greeting;
  List<String> get _suggestionList => widget.ideaMode ? _ideaSuggestions : _suggestions;
  bool _sending = false;
  String? _error;
  AiUsage? _usage;

  @override
  void initState() {
    super.initState();
    _assistantService = AssistantService(context.read<ApiClient>());
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    try {
      final usage = await _assistantService.getUsage(widget.businessId);
      if (mounted) setState(() => _usage = usage);
    } on ApiException {
      // Sin el contador el chat igual funciona; el backend es quien aplica el límite.
    }
  }

  Future<void> _openPlans() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen()));
    // Puede haber mejorado su plan: se vuelve a consultar cuántas consultas le quedan.
    await _loadUsage();
    if (mounted && !(_usage?.isExhausted ?? false)) setState(() => _error = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || (_usage?.isExhausted ?? false)) return;

    final history = _messages.map((m) => {'role': m.role, 'content': m.content}).toList(growable: false);

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _controller.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final result = await _assistantService.sendMessage(widget.businessId, text, history: history);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: result.reply));
        _usage = result.usage ?? _usage;
        _sending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final limitReached = e.details?.any((d) => d['message'] == AssistantService.dailyLimitCode) ?? false;
      setState(() {
        _sending = false;
        if (limitReached) {
          // La pregunta no se respondió: se devuelve al campo para que no se pierda.
          _messages.removeLast();
          _controller.text = text;
          _usage = AiUsage(limit: _usage?.limit, used: _usage?.limit ?? 0, remaining: 0);
        } else {
          _error = e.message;
        }
      });
    } finally {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showSuggestions() async {
    final question = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Preguntas sugeridas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
            for (final suggestion in _suggestionList)
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary),
                title: Text(suggestion),
                onTap: () => Navigator.of(sheetContext).pop(suggestion),
              ),
          ],
        ),
      ),
    );
    if (question == null) return;
    _controller.text = question;
    await _send();
  }

  void _newConversation() {
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMessage(role: 'assistant', content: _greetingText));
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exhausted = _usage?.isExhausted ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            // Destellos y onda decorativos del fondo.
            Positioned(
              right: 40,
              bottom: 170,
              child: Icon(Icons.auto_awesome, size: 56, color: const Color(0xFF7C3AED).withValues(alpha: 0.12)),
            ),
            Positioned(
              right: -120,
              bottom: -60,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(160),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _Header(onNewConversation: _messages.length > 1 ? _newConversation : null, onPlans: _openPlans),
                  if (_usage != null && _usage!.isLimited && !exhausted)
                    _UsageBanner(usage: _usage!, onUpgrade: _openPlans),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) =>
                          index >= _messages.length ? const _TypingBubble() : _MessageBubble(message: _messages[index]),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (exhausted)
                    _LimitReachedCard(limit: _usage!.limit ?? 0, onUpgrade: _openPlans)
                  else
                    _InputBar(
                      controller: _controller,
                      sending: _sending,
                      onSend: _send,
                      onSuggestions: _sending ? null : _showSuggestions,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  final double size;

  const _BotAvatar({this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D8BFF), Color(0xFF1A5FD8)],
        ),
      ),
      child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: size * 0.56),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onNewConversation;
  final VoidCallback onPlans;

  const _Header({required this.onNewConversation, required this.onPlans});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              children: [
                const Positioned(left: 0, bottom: 0, child: _BotAvatar(size: 50)),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(Icons.auto_awesome, size: 20, color: AppTheme.primary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente de IA',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                Text('Tu aliado en ventas y productos', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: AppTheme.navy.withValues(alpha: 0.2),
            child: PopupMenuButton<String>(
              tooltip: 'Opciones',
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
              onSelected: (value) => value == 'new' ? onNewConversation?.call() : onPlans(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'new',
                  enabled: onNewConversation != null,
                  child: const Row(
                    children: [Icon(Icons.refresh_rounded, size: 20), SizedBox(width: 10), Text('Nueva conversación')],
                  ),
                ),
                const PopupMenuItem(
                  value: 'plans',
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Ver planes'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBanner extends StatelessWidget {
  final AiUsage usage;
  final VoidCallback onUpgrade;

  const _UsageBanner({required this.usage, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final remaining = usage.remaining ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(color: const Color(0xFFE6EFFE), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 26, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining == 1
                  ? 'Te queda 1 de ${usage.limit} consultas hoy'
                  : 'Te quedan $remaining de ${usage.limit} consultas hoy',
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onUpgrade,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mejorar plan',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: AppTheme.primary, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final maxWidth = MediaQuery.sizeOf(context).width * (isUser ? 0.75 : 0.68);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: isUser ? AppTheme.primary : const Color(0xFFE9EDF4),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(color: isUser ? Colors.white : AppTheme.textPrimary, fontSize: 15, height: 1.4),
      ),
    );
    final time = Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
      child: Text(_formatTime(message.sentAt), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: isUser
          ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [bubble, time])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BotAvatar(),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bubble, time]),
              ],
            ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const _BotAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFE9EDF4), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Pensando…', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback? onSuggestions;

  const _InputBar({required this.controller, required this.sending, required this.onSend, this.onSuggestions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      color: const Color(0xFFEFF2F7),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Preguntas sugeridas',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_rounded, color: AppTheme.textSecondary),
                        onPressed: onSuggestions,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu pregunta...',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(4, 16, 12, 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            height: 60,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(60, 60),
              ),
              onPressed: sending ? null : onSend,
              child: const Icon(Icons.send_rounded, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitReachedCard extends StatelessWidget {
  final int limit;
  final VoidCallback onUpgrade;

  const _LimitReachedCard({required this.limit, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Llegaste al límite de hoy',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tu plan incluye $limit consultas al día. Vuelve mañana o pasa al plan Crecimiento '
            'para usar el asistente sin límites.',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onUpgrade,
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Ver planes'),
          ),
        ],
      ),
    );
  }
}
