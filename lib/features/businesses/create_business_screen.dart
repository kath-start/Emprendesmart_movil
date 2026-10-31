import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/business_categories.dart';
import '../../core/utils/labels.dart';
import '../../models/business.dart';
import 'business_provider.dart';

const _stages = ['IDEA', 'EARLY', 'GROWTH', 'ESTABLISHED'];
const _statuses = ['ACTIVE', 'INACTIVE', 'CLOSED'];

const _fieldText = TextStyle(fontSize: 16, color: AppTheme.textPrimary);
const _fieldFill = Color(0xFFF7F9FD);
const _iconCircle = Color(0xFFE6EFFE);

class CreateBusinessScreen extends StatefulWidget {
  final Business? existingBusiness;

  const CreateBusinessScreen({super.key, this.existingBusiness});

  bool get isEditing => existingBusiness != null;

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existingBusiness?.name);
  late BusinessCategory? _category = _initialCategory;
  // Texto de la categoría cuando se elige "Otro" (o cuando la guardada no está en la lista).
  // Solo se precarga si la categoría guardada del negocio es personalizada.
  late final _customCategoryController = TextEditingController(
    text: _initialCategory == BusinessCategories.other ? widget.existingBusiness?.category : null,
  );
  late final _descriptionController = TextEditingController(text: widget.existingBusiness?.description);
  late String _stage = widget.existingBusiness?.stage ?? _stages.first;
  late String _status = widget.existingBusiness?.status ?? _statuses.first;
  String? _errorMessage;
  bool _showCategoryError = false;

  BusinessCategory? get _initialCategory {
    final saved = widget.existingBusiness?.category.trim() ?? '';
    if (saved.isEmpty) return null;
    return BusinessCategories.find(saved) ?? BusinessCategories.other;
  }

  String get _categoryText =>
      _category == BusinessCategories.other ? _customCategoryController.text.trim() : _category?.name ?? '';

  @override
  void dispose() {
    _nameController.dispose();
    _customCategoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    setState(() => _showCategoryError = _category == null);
    if (!formValid || _category == null) return;
    setState(() => _errorMessage = null);
    try {
      final provider = context.read<BusinessProvider>();
      if (widget.isEditing) {
        await provider.updateBusiness(
          widget.existingBusiness!.id,
          name: _nameController.text.trim(),
          category: _categoryText,
          description: _descriptionController.text.trim(),
          stage: _stage,
          status: _status,
        );
      } else {
        await provider.createBusiness(
          name: _nameController.text.trim(),
          category: _categoryText,
          description: _descriptionController.text.trim(),
          stage: _stage,
        );
      }
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<BusinessProvider>().isLoading;
    final editing = widget.isEditing;
    String? required(String? value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                title: editing ? 'Editar negocio' : 'Cuéntanos de tu negocio',
                subtitle: editing
                    ? 'Actualiza la información de tu negocio'
                    : 'Registra tu negocio, sea del rubro que sea, para gestionar productos y ventas',
                canPop: Navigator.of(context).canPop(),
                category: _category,
              ),
              const Divider(height: 1, color: AppTheme.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _FieldLabel('Nombre del negocio'),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.sentences,
                              style: _fieldText,
                              decoration: _decoration(icon: Icons.storefront_outlined, hint: 'Ej. Mi Tienda'),
                              validator: required,
                            ),
                            const SizedBox(height: 18),
                            const _FieldLabel('¿A qué se dedica tu negocio?'),
                            _CategoryGrid(
                              selected: _category,
                              onSelected: (category) => setState(() {
                                _category = category;
                                _showCategoryError = false;
                              }),
                            ),
                            if (_showCategoryError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Text(
                                  'Elige un tipo de negocio',
                                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                                ),
                              ),
                            if (_category == BusinessCategories.other) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _customCategoryController,
                                textCapitalization: TextCapitalization.sentences,
                                style: _fieldText,
                                decoration: _decoration(
                                  icon: Icons.edit_outlined,
                                  hint: 'Escribe el rubro (ej. Ferretería)',
                                ),
                                validator: required,
                              ),
                            ],
                            const SizedBox(height: 18),
                            const _FieldLabel('Descripción (opcional)'),
                            _DescriptionField(controller: _descriptionController),
                            const SizedBox(height: 18),
                            const _FieldLabel('¿En qué etapa está?'),
                            _StageGrid(selected: _stage, onSelected: (stage) => setState(() => _stage = stage)),
                            if (editing) ...[
                              const SizedBox(height: 18),
                              const _FieldLabel('Estado'),
                              DropdownButtonFormField<String>(
                                initialValue: _status,
                                style: _fieldText,
                                borderRadius: BorderRadius.circular(16),
                                dropdownColor: Colors.white,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
                                decoration: _decoration(prefix: _StatusDot(color: _statusColor(_status))),
                                items: _statuses
                                    .map((status) => DropdownMenuItem(value: status, child: Text(Labels.status(status))))
                                    .toList(),
                                onChanged: (value) => setState(() => _status = value ?? _statuses.first),
                              ),
                            ],
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ],
                            const SizedBox(height: 28),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
                                shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                              ),
                              onPressed: isLoading ? null : _submit,
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(editing ? Icons.save_outlined : Icons.add_business_outlined),
                              label: Text(
                                editing ? 'Guardar cambios' : 'Crear negocio',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo con fondo suave, esquinas redondeadas e ícono a la izquierda, como en el diseño.
InputDecoration _decoration({IconData? icon, Widget? prefix, String? hint}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );

  final leading = prefix ?? (icon == null ? null : Icon(icon, size: 24));

  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: _fieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    prefixIcon: leading == null
        ? null
        : Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: leading),
    prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 24),
    prefixIconColor: AppTheme.textSecondary,
    border: border(AppTheme.border),
    enabledBorder: border(AppTheme.border),
    focusedBorder: border(AppTheme.primary.withValues(alpha: 0.6), 1.5),
  );
}

/// Descripción de varias líneas: el ícono queda arriba y el contador dentro de la caja.
/// (El prefixIcon de InputDecoration siempre se centra verticalmente.)
class _DescriptionField extends StatefulWidget {
  final TextEditingController controller;

  const _DescriptionField({required this.controller});

  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<_DescriptionField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused ? AppTheme.primary.withValues(alpha: 0.6) : AppTheme.border,
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16, right: 14),
            child: Icon(Icons.description_outlined, size: 24, color: AppTheme.textSecondary),
          ),
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focus,
              style: _fieldText,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Escribe una breve descripción de tu negocio...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 17, bottom: 4),
                counterStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _stageIcon(String stage) => switch (stage) {
  'IDEA' => Icons.lightbulb_outline_rounded,
  'EARLY' => Icons.rocket_launch_outlined,
  'GROWTH' => Icons.trending_up_rounded,
  _ => Icons.workspace_premium_outlined,
};

String _stageDescription(String stage) => switch (stage) {
  'IDEA' => 'Lo estoy planeando',
  'EARLY' => 'Recién empecé a vender',
  'GROWTH' => 'Vendo seguido y quiero crecer',
  _ => 'Negocio estable y conocido',
};

/// Tipos de negocio en cuadrícula de 3 columnas, más "Otro" para escribir uno propio.
class _CategoryGrid extends StatelessWidget {
  final BusinessCategory? selected;
  final ValueChanged<BusinessCategory> onSelected;

  const _CategoryGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const options = [...BusinessCategories.all, BusinessCategories.other];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final category in options)
          _SelectableTile(
            selected: category == selected,
            color: category.color,
            onTap: () => onSelected(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: category.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(category.icon, color: category.color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Etapas del negocio en tarjetas de 2 columnas con ícono y una frase que la explica.
class _StageGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _StageGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: [
        for (final stage in _stages)
          _SelectableTile(
            selected: stage == selected,
            color: AppTheme.primary,
            onTap: () => onSelected(stage),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    _stageIcon(stage),
                    size: 24,
                    color: stage == selected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Labels.businessStage(stage),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        Text(
                          _stageDescription(stage),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, height: 1.2, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta seleccionable: borde y fondo del color indicado cuando está elegida, con un check.
class _SelectableTile extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  const _SelectableTile({required this.selected, required this.color, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.08) : _fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.8 : 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              if (selected)
                Positioned(top: 6, right: 6, child: Icon(Icons.check_circle_rounded, size: 16, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
  'ACTIVE' => const Color(0xFF22C55E),
  'INACTIVE' => const Color(0xFFF59E0B),
  _ => const Color(0xFFEF4444),
};

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool canPop;
  final BusinessCategory? category;

  const _Header({required this.title, required this.subtitle, required this.canPop, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFF4FD), Colors.white],
        ),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            Material(
              color: _iconCircle,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // El ícono cambia según el tipo de negocio elegido.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Container(
              key: ValueKey(category?.name),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: category == null ? _iconCircle : category!.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category?.icon ?? Icons.storefront_rounded,
                color: category?.color ?? AppTheme.primary,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
