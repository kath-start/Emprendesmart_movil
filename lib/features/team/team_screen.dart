import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/business.dart';
import '../plans/plans_screen.dart';
import 'team_service.dart';

const _roleColors = {BusinessRole.partner: Color(0xFF7C3AED), BusinessRole.cashier: Color(0xFF10B981)};

const _roleDescriptions = {
  BusinessRole.partner: 'Vende, maneja productos e inventario y ve alertas y la IA. No puede borrar productos.',
  BusinessRole.cashier: 'Solo registra ventas.',
};

/// Equipo del negocio: el dueño (plan Pro) invita a su socio o a su cajero(a) por correo.
class TeamScreen extends StatefulWidget {
  final Business business;

  const TeamScreen({super.key, required this.business});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final TeamService _service = TeamService(context.read<ApiClient>());
  Team? _team;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final team = await _service.get(widget.business.id);
      if (mounted) setState(() => _team = team);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPlans() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen()));
    await _load();
  }

  Future<void> _addMember() async {
    final added = await showModalBottomSheet<TeamMember>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMemberSheet(service: _service, businessId: widget.business.id),
    );
    if (added == null) return;
    await _load();
    _showMessage(
      added.registered
          ? '${added.name ?? added.email} ya puede entrar a ${widget.business.name}'
          : 'Invitación guardada. Debe registrarse en la app con ${added.email}',
    );
  }

  Future<void> _changeRole(TeamMember member, BusinessRole role) async {
    try {
      await _service.changeRole(widget.business.id, member.id, role);
      await _load();
      _showMessage('Ahora es ${role.label.toLowerCase()}');
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _remove(TeamMember member) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Quitar del equipo?',
      message: '**${member.name ?? member.email}** ya no podrá entrar a **${widget.business.name}**.',
      icon: Icons.person_remove_outlined,
      confirmLabel: 'Quitar',
    );
    if (confirmed != true) return;
    try {
      await _service.remove(widget.business.id, member.id);
      await _load();
      _showMessage('Se quitó el acceso');
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    final canAdd = team != null && team.enabled && team.members.length < team.maxMembers;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        floatingActionButton: canAdd
            ? FloatingActionButton.extended(
                onPressed: _addMember,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Agregar persona'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(businessName: widget.business.name),
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), child: _buildBody(team)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Team? team) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (team == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!team.enabled) return _UpgradeCard(onUpgrade: _openPlans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RolesCard(),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Personas del equipo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
            Text(
              '${team.members.length} de ${team.maxMembers}',
              style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (team.members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Todavía estás solo(a).\nToca "Agregar persona" para sumar a tu socio o cajero(a).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
          )
        else
          for (final member in team.members)
            _MemberTile(
              member: member,
              onChangeRole: (role) => _changeRole(member, role),
              onRemove: () => _remove(member),
            ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String businessName;

  const _Header({required this.businessName});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedBottomClipper(),
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 8, 16, 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mi equipo',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quiénes te ayudan en $businessName',
                      style: const TextStyle(color: Color(0xFFDCE8FF), height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 20)
      ..quadraticBezierTo(size.width / 2, size.height + 4, size.width, size.height - 20)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RolesCard extends StatelessWidget {
  const _RolesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RoleLine(
            icon: Icons.verified_user_rounded,
            color: AppTheme.primary,
            title: 'Tú (dueño)',
            text: 'Controlas todo y puedes quitarle el acceso a cualquiera.',
          ),
          for (final role in [BusinessRole.partner, BusinessRole.cashier])
            _RoleLine(
              icon: role == BusinessRole.partner ? Icons.handshake_rounded : Icons.point_of_sale_rounded,
              color: _roleColors[role]!,
              title: role.label,
              text: _roleDescriptions[role]!,
            ),
        ],
      ),
    );
  }
}

class _RoleLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _RoleLine({required this.icon, required this.color, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final TeamMember member;
  final ValueChanged<BusinessRole> onChangeRole;
  final VoidCallback onRemove;

  const _MemberTile({required this.member, required this.onChangeRole, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final color = _roleColors[member.role] ?? AppTheme.primary;
    final initial = (member.name ?? member.email).characters.first.toUpperCase();
    final otherRole = member.role == BusinessRole.partner ? BusinessRole.cashier : BusinessRole.partner;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Text(
            initial,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          member.name ?? member.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.name != null) Text(member.email, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Chip(label: member.role.label, color: color),
                if (!member.registered) const _Chip(label: 'Falta que se registre', color: Color(0xFFF59E0B)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones',
          onSelected: (value) => value == 'remove' ? onRemove() : onChangeRole(otherRole),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'role', child: Text('Cambiar a ${otherRole.label.toLowerCase()}')),
            const PopupMenuItem(
              value: 'remove',
              child: Text('Quitar del equipo', style: TextStyle(color: Color(0xFFDC2626))),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _UpgradeCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFF7C3AED), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Trabaja en equipo con el plan Pro',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Suma hasta 5 personas a tu negocio, cada una con su propia cuenta: tu socio maneja '
            'productos e inventario, y tu cajero(a) solo registra ventas. Tú controlas todo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: onUpgrade,
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Ver plan Pro'),
          ),
        ],
      ),
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  final TeamService service;
  final String businessId;

  const _AddMemberSheet({required this.service, required this.businessId});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  BusinessRole _role = BusinessRole.cashier;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final member = await widget.service.add(widget.businessId, email: _emailController.text.trim(), role: _role);
      if (mounted) Navigator.of(context).pop(member);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Agregar persona',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Entrará a la app con su propio correo y contraseña.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: (value) {
                final email = value?.trim() ?? '';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Escribe un correo válido';
              },
            ),
            const SizedBox(height: 16),
            for (final role in [BusinessRole.cashier, BusinessRole.partner])
              _RoleOption(role: role, selected: _role == role, onTap: () => setState(() => _role = role)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Agregar al equipo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final BusinessRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _roleColors[role]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? color.withValues(alpha: 0.08) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? color : AppTheme.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? color : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.label,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _roleDescriptions[role]!,
                        style: const TextStyle(color: AppTheme.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
