import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/labels.dart';
import '../../models/entrepreneur.dart';
import '../plans/plans_screen.dart';
import 'auth_provider.dart';

/// Pantallas que se abren desde cada dato de "Mi perfil".

/// Nombre y apellidos.
class EditNameScreen extends StatefulWidget {
  final Entrepreneur entrepreneur;

  const EditNameScreen({super.key, required this.entrepreneur});

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.entrepreneur.firstName);
  late final _lastName = TextEditingController(text: widget.entrepreneur.lastName);

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? value) => (value == null || value.trim().isEmpty) ? 'Este dato es obligatorio' : null;

    return _EditScaffold(
      icon: Icons.person_outline_rounded,
      color: AppTheme.primary,
      title: 'Nombre',
      subtitle: 'Así te saludamos en la app y te ve tu equipo.',
      formKey: _formKey,
      onSave: () => context.read<AuthProvider>().updateProfile({
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
      }),
      successMessage: 'Nombre actualizado',
      children: [
        _Field(
          controller: _firstName,
          label: 'Nombres',
          icon: Icons.badge_outlined,
          validator: required,
          capitalization: TextCapitalization.words,
          maxLength: 80,
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _lastName,
          label: 'Apellidos',
          icon: Icons.badge_outlined,
          validator: required,
          capitalization: TextCapitalization.words,
          maxLength: 80,
        ),
      ],
    );
  }
}

/// Un solo texto opcional, como la ciudad (vacío = se borra el dato).
class EditTextFieldScreen extends StatefulWidget {
  final String field;
  final String title;
  final String subtitle;
  final String label;
  final IconData icon;
  final Color color;
  final String? initialValue;
  final TextInputType keyboardType;
  final int maxLength;

  const EditTextFieldScreen({
    super.key,
    required this.field,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.icon,
    required this.color,
    required this.initialValue,
    this.keyboardType = TextInputType.text,
    this.maxLength = 80,
  });

  /// Ciudad donde está el negocio.
  factory EditTextFieldScreen.city(Entrepreneur e) => EditTextFieldScreen(
    field: 'city',
    title: 'Ciudad',
    subtitle: 'La ciudad donde trabajas o está tu negocio.',
    label: 'Ciudad',
    icon: Icons.location_on_outlined,
    color: const Color(0xFFEC4899),
    initialValue: e.city,
  );

  @override
  State<EditTextFieldScreen> createState() => _EditTextFieldScreenState();
}

class _EditTextFieldScreenState extends State<EditTextFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialValue ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      icon: widget.icon,
      color: widget.color,
      title: widget.title,
      subtitle: widget.subtitle,
      formKey: _formKey,
      onSave: () => context.read<AuthProvider>().updateProfile({widget.field: _controller.text.trim()}),
      successMessage: '${widget.title} actualizado',
      hint: 'Déjalo vacío si prefieres no guardarlo.',
      children: [
        _Field(
          controller: _controller,
          label: widget.label,
          icon: widget.icon,
          keyboardType: widget.keyboardType,
          maxLength: widget.maxLength,
          capitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}

/// Teléfono: código del país (con bandera) + número agrupado de a 3 dígitos.
class EditPhoneScreen extends StatefulWidget {
  final Entrepreneur entrepreneur;

  const EditPhoneScreen({super.key, required this.entrepreneur});

  @override
  State<EditPhoneScreen> createState() => _EditPhoneScreenState();
}

class _EditPhoneScreenState extends State<EditPhoneScreen> {
  static const _color = Color(0xFF1A73F0);
  static const _maxDigits = 12;

  final _formKey = GlobalKey<FormState>();
  late String _country;
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    final parts = splitPhone(widget.entrepreneur.phone, preferredCountry: widget.entrepreneur.country);
    _country = parts.country;
    _number = TextEditingController(text: groupPhoneDigits(parts.number));
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  String get _digits => _number.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _DialCodeSheet(selected: _country),
    );
    if (picked != null && mounted) setState(() => _country = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dial = countryDialCodes[_country]!;
    return _EditScaffold(
      icon: Icons.phone_rounded,
      color: _color,
      title: 'Teléfono',
      subtitle: 'Tu número de contacto, por ejemplo +51 987 654 321.',
      illustration: const _PhoneIllustration(),
      formKey: _formKey,
      // Vacío = se borra el teléfono.
      onSave: () => context.read<AuthProvider>().updateProfile({
        'phone': _digits.isEmpty ? '' : '$dial ${groupPhoneDigits(_digits)}',
      }),
      successMessage: 'Teléfono actualizado',
      hint: 'Déjalo vacío si prefieres no guardarlo.',
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 10),
          child: Row(
            children: [
              Icon(Icons.phone_rounded, color: _color, size: 24),
              SizedBox(width: 10),
              Text(
                'Teléfono',
                style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 18, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFC5D6F6), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bandera + código: se toca para elegir otro país.
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickCountry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      _Flag(country: _country, width: 44, height: 30),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textPrimary, size: 26),
                      const SizedBox(width: 10),
                      Text(dial, style: const TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
              Container(
                width: 2,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: _color.withValues(alpha: 0.5),
              ),
              Expanded(
                child: TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 24, color: AppTheme.textPrimary, letterSpacing: 0.5),
                  inputFormatters: [_GroupedDigitsFormatter(_maxDigits)],
                  decoration: const InputDecoration(
                    hintText: '987 654 321',
                    hintStyle: TextStyle(color: Color(0xFFA9B6CC)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  validator: (_) => _digits.isEmpty || _digits.length >= 6 ? null : 'Ingresa un número válido',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Deja solo dígitos (hasta [maxDigits]) y los agrupa de a 3: "929020723" → "929 020 723".
class _GroupedDigitsFormatter extends TextInputFormatter {
  final int maxDigits;

  _GroupedDigitsFormatter(this.maxDigits);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final text = groupPhoneDigits(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Lista de países con bandera y código telefónico. Devuelve el país elegido.
class _DialCodeSheet extends StatelessWidget {
  final String selected;

  const _DialCodeSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final countries = countryDialCodes.keys.toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Código de país',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: countries.length,
              itemBuilder: (context, i) {
                final country = countries[i];
                final isSelected = country == selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected ? const Color(0xFFE6EFFE) : const Color(0xFFF6F8FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isSelected ? const BorderSide(color: AppTheme.primary, width: 1.3) : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: () => Navigator.of(context).pop(country),
                      leading: _Flag(country: country, width: 44, height: 30),
                      title: Text(
                        country,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      trailing: Text(
                        countryDialCodes[country]!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final _countries = countryCodes.keys.toList();

/// País: lista con buscador; al tocar uno se guarda.
class EditCountryScreen extends StatefulWidget {
  final Entrepreneur entrepreneur;

  const EditCountryScreen({super.key, required this.entrepreneur});

  @override
  State<EditCountryScreen> createState() => _EditCountryScreenState();
}

class _EditCountryScreenState extends State<EditCountryScreen> {
  static const _color = Color(0xFF14B8A6);
  String _query = '';
  String? _saving;

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  Future<void> _select(String country) async {
    if (_saving != null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = country);
    try {
      await context.read<AuthProvider>().updateProfile({'country': country});
      messenger.showSnackBar(const SnackBar(content: Text('País actualizado')));
      navigator.pop();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.entrepreneur.country;
    final query = _normalize(_query.trim());
    final options = [
      // Un país guardado que no está en la lista igual se muestra para no perderlo.
      if (current != null && !_countries.contains(current)) current,
      ..._countries,
    ].where((c) => query.isEmpty || _normalize(c).contains(query)).toList();

    return _ScreenFrame(
      icon: Icons.public_rounded,
      color: _color,
      title: 'País',
      subtitle: 'Elige el país donde está tu negocio',
      illustration: const _GlobeIllustration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 17, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar país…',
              hintStyle: const TextStyle(color: Color(0xFF8A9BBA), fontSize: 17),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 18, right: 10),
                child: Icon(Icons.search_rounded, color: Color(0xFF5B6B85), size: 28),
              ),
              filled: true,
              fillColor: const Color(0xFFF1F5FD),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFD6E1F5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFD6E1F5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'No encontramos ese país.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            ),
          for (final country in options)
            _CountryCard(
              country: country,
              selected: country == current,
              saving: _saving == country,
              onTap: country == current ? () => Navigator.of(context).pop() : () => _select(country),
            ),
        ],
      ),
    );
  }
}

/// Un país de la lista: bandera, nombre y flecha; el elegido va resaltado con un check.
class _CountryCard extends StatelessWidget {
  final String country;
  final bool selected;
  final bool saving;
  final VoidCallback onTap;

  const _CountryCard({required this.country, required this.selected, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? const Color(0xFFE6EFFE) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected ? const BorderSide(color: AppTheme.primary, width: 1.5) : BorderSide.none,
        ),
        elevation: selected ? 0 : 2,
        shadowColor: AppTheme.navy.withValues(alpha: 0.18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                _Flag(country: country),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    country,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                if (saving)
                  const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
                else if (selected)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF5B6B85), size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Email: es el usuario para iniciar sesión, por eso se confirma con la contraseña.
class ChangeEmailScreen extends StatefulWidget {
  final Entrepreneur entrepreneur;

  const ChangeEmailScreen({super.key, required this.entrepreneur});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditScaffold(
      icon: Icons.mail_outline_rounded,
      color: const Color(0xFF7C3AED),
      title: 'Email',
      subtitle: 'Con este correo inicias sesión en EmprendeSmart.',
      formKey: _formKey,
      saveLabel: 'Cambiar email',
      onSave: () => context.read<AuthProvider>().changeEmail(newEmail: _email.text.trim(), password: _password.text),
      successMessage: 'Email actualizado. Úsalo la próxima vez que inicies sesión.',
      hint: 'Si trabajas en el equipo de otro negocio, pídele al dueño que te vuelva a agregar con tu nuevo correo.',
      children: [
        _WhiteCard(
          child: Row(
            children: [
              const Icon(Icons.alternate_email_rounded, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email actual', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    Text(
                      widget.entrepreneur.email,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _email,
          label: 'Nuevo email',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final email = (value ?? '').trim();
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Ingresa un email válido';
            if (email.toLowerCase() == widget.entrepreneur.email.toLowerCase()) return 'Es tu email actual';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _Field(
          controller: _password,
          label: 'Tu contraseña',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu contraseña' : null,
        ),
      ],
    );
  }
}

/// Estado de la cuenta (solo lectura).
class AccountStatusScreen extends StatelessWidget {
  final Entrepreneur entrepreneur;

  const AccountStatusScreen({super.key, required this.entrepreneur});

  @override
  Widget build(BuildContext context) {
    final active = entrepreneur.status == 'ACTIVE';
    final statusColor = active ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return _ScreenFrame(
      icon: Icons.verified_user_outlined,
      color: const Color(0xFFF59E0B),
      title: 'Estado de la cuenta',
      subtitle: 'Revisa si tu cuenta está habilitada.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WhiteCard(
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(active ? Icons.verified_rounded : Icons.block_rounded, color: statusColor, size: 42),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cuenta ${Labels.status(entrepreneur.status).toLowerCase()}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: statusColor),
                ),
                const SizedBox(height: 6),
                Text(
                  active
                      ? 'Puedes usar todas las funciones de tu plan sin restricciones.'
                      : 'Tu cuenta tiene el acceso limitado. Escríbenos para revisarla.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _StatusRow(icon: Icons.mail_outline_rounded, label: 'Cuenta', value: entrepreneur.email),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE6ECF5)),
                _StatusRow(
                  icon: Icons.credit_card_rounded,
                  label: 'Plan',
                  value: Labels.plan(entrepreneur.plan),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE6ECF5)),
                _StatusRow(icon: Icons.shield_outlined, label: 'Acceso', value: active ? 'Habilitado' : 'Restringido'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatusRow({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Icon(icon, color: AppTheme.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 16),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas compartidas
// ---------------------------------------------------------------------------

/// Formulario con botón "Guardar": valida, llama a [onSave], avisa y vuelve al perfil.
class _EditScaffold extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final Future<void> Function() onSave;
  final String successMessage;
  final String saveLabel;
  final String? hint;
  final Widget? illustration;
  final List<Widget> children;

  const _EditScaffold({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.onSave,
    required this.successMessage,
    required this.children,
    this.saveLabel = 'Guardar cambios',
    this.hint,
    this.illustration,
  });

  @override
  State<_EditScaffold> createState() => _EditScaffoldState();
}

class _EditScaffoldState extends State<_EditScaffold> {
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!widget.formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      messenger.showSnackBar(SnackBar(content: Text(widget.successMessage)));
      navigator.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(
      icon: widget.icon,
      color: widget.color,
      title: widget.title,
      subtitle: widget.subtitle,
      illustration: widget.illustration,
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...widget.children,
            if (widget.hint != null) ...[const SizedBox(height: 16), _HintBox(text: widget.hint!)],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 24),
            _GradientButton(label: widget.saveLabel, loading: _saving, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}

/// Encabezado azul con curva (volver + ícono + título + ilustración) y contenido desplazable.
class _ScreenFrame extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  /// Dibujo a la derecha del encabezado; si no hay, se muestra el ícono grande y tenue.
  final Widget? illustration;

  const _ScreenFrame({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomPaint(
          painter: _SoftWavesPainter(),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ClipPath(
                clipper: _WaveBottomClipper(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF071C4D), Color(0xFF0B2F7A), Color(0xFF1748B0)],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(20, top + 12, 20, 56),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -10,
                        top: -4,
                        child: illustration == null
                            ? Icon(icon, size: 150, color: Colors.white.withValues(alpha: 0.08))
                            // Un poco más chica para que no tape el título.
                            : Transform.scale(scale: 0.85, alignment: Alignment.topRight, child: illustration),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Volver',
                              iconSize: 28,
                              padding: const EdgeInsets.all(12),
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(icon, color: Colors.white, size: 38),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  // Con ilustración, el texto deja libre la derecha para no quedar debajo del dibujo.
                                  padding: EdgeInsets.only(right: illustration == null ? 0 : 110),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 15,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ondas celestes al pie de la pantalla, como fondo decorativo.
class _SoftWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final back = Path()
      ..moveTo(0, h - 330)
      ..quadraticBezierTo(w * 0.3, h - 250, w * 0.55, h - 300)
      ..quadraticBezierTo(w * 0.8, h - 350, w, h - 420)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final front = Path()
      ..moveTo(0, h - 240)
      ..quadraticBezierTo(w * 0.35, h - 130, w * 0.62, h - 200)
      ..quadraticBezierTo(w * 0.85, h - 260, w, h - 300)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = AppTheme.primary.withValues(alpha: 0.05));
    canvas.drawPath(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primary.withValues(alpha: 0.10), AppTheme.primary.withValues(alpha: 0.04)],
        ).createShader(Rect.fromLTWH(0, h - 300, w, 300)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Aviso celeste con una "i" azul.
class _HintBox extends StatelessWidget {
  final String text;

  const _HintBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFEAF1FE), Color(0xFFDDE8FC)]),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            child: const Text(
              'i',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Botón principal azul con degradado: ícono de guardar, texto y flecha.
class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _GradientButton({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null && !loading ? 0.6 : 1,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF2F86FF), Color(0xFF0F52DB)]),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        ),
                      )
                    : Row(
                        children: [
                          const Spacer(),
                          const Icon(Icons.sync_rounded, color: Colors.white, size: 30),
                          const SizedBox(width: 14),
                          Text(
                            label,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 30),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Celular inclinado con un anillo de luz (encabezado de "Teléfono").
class _PhoneIllustration extends StatelessWidget {
  const _PhoneIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 170,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Brillo y parte trasera del anillo.
          Positioned(
            left: 4,
            top: 70,
            child: CustomPaint(size: const Size(170, 70), painter: _RingPainter(back: true)),
          ),
          Transform.rotate(
            angle: 0.28,
            child: Container(
              width: 82,
              height: 148,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF5B9BFF), width: 3),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2556C9), Color(0xFF0B2766)],
                ),
                boxShadow: [BoxShadow(color: const Color(0xFF3D8BFF).withValues(alpha: 0.6), blurRadius: 22)],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 6,
                    child: Container(
                      width: 26,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const Icon(Icons.phone_rounded, color: Colors.white, size: 42),
                ],
              ),
            ),
          ),
          // Parte delantera del anillo, que pasa por encima del celular.
          Positioned(
            left: 4,
            top: 70,
            child: CustomPaint(size: const Size(170, 70), painter: _RingPainter(back: false)),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final bool back;

  _RingPainter({required this.back});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.18);
    canvas.translate(-size.width / 2, -size.height / 2);
    final glow = Paint()
      ..color = const Color(0xFF4FA3FF).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..color = const Color(0xFFBFE0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Atrás: mitad superior del óvalo; adelante: mitad inferior.
    final start = back ? 3.14159 : 0.0;
    canvas.drawArc(rect, start, 3.14159, false, glow);
    canvas.drawArc(rect, start, 3.14159, false, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.back != back;
}

class _WaveBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 18)
    ..quadraticBezierTo(size.width * 0.28, size.height - 46, size.width * 0.62, size.height - 30)
    ..quadraticBezierTo(size.width * 0.86, size.height - 18, size.width, size.height - 50)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Globo terráqueo con órbita, pin de ubicación y avión de papel (encabezado de "País").
class _GlobeIllustration extends StatelessWidget {
  const _GlobeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Trayecto punteado del avión.
          Positioned.fill(child: CustomPaint(painter: _DashedFlightPainter())),
          Positioned(
            left: 18,
            top: 6,
            child: Transform.rotate(
              angle: -0.5,
              child: Icon(Icons.send_rounded, color: Colors.white.withValues(alpha: 0.75), size: 30),
            ),
          ),
          // Globo.
          Positioned(
            right: 8,
            top: 10,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.35),
                  colors: [Color(0xFF5FA8FF), Color(0xFF1D5FD6), Color(0xFF0E3A93)],
                ),
                boxShadow: [BoxShadow(color: const Color(0xFF3D8BFF).withValues(alpha: 0.45), blurRadius: 24)],
              ),
              child: Icon(Icons.public_rounded, size: 104, color: Colors.white.withValues(alpha: 0.28)),
            ),
          ),
          // Órbita alrededor del globo.
          Positioned(
            right: -8,
            top: 52,
            child: CustomPaint(size: const Size(150, 50), painter: _OrbitPainter()),
          ),
          // Pin de ubicación.
          const Positioned(
            right: 0,
            top: 0,
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 40,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.25);
    // Solo el arco delantero, para que parezca pasar por delante del globo.
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height * 0.7),
      0.15,
      2.6,
      false,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedFlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..moveTo(30, 30)
      ..quadraticBezierTo(-10, 70, 20, 105)
      ..quadraticBezierTo(45, 125, 75, 118);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 4.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _WhiteCard({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon),
  suffixIcon: suffix,
  filled: true,
  fillColor: Colors.white,
  counterText: '',
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: AppTheme.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: AppTheme.border),
  ),
);

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final int? maxLength;
  final bool obscureText;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.maxLength,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      maxLength: maxLength,
      obscureText: obscureText,
      decoration: _inputDecoration(label, icon, suffix: suffix),
    );
  }
}

/// Bandera rectangular del país (imagen de flagcdn.com); sin conexión, el emoji; país desconocido, un globo.
class _Flag extends StatelessWidget {
  final String country;
  final double width;
  final double height;

  const _Flag({required this.country, this.width = 58, this.height = 40});

  @override
  Widget build(BuildContext context) {
    final code = countryCodes[country];
    final emoji = countryFlag(country);
    Widget fallback() => Center(
      child: emoji == null
          ? const Icon(Icons.public_rounded, color: AppTheme.textSecondary)
          : Text(emoji, style: const TextStyle(fontSize: 26)),
    );

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: AppTheme.navy.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: code == null
          ? fallback()
          : Image.network(
              'https://flagcdn.com/w160/${code.toLowerCase()}.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
  }
}
