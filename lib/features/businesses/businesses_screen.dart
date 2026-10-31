import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../../models/business.dart';
import 'business_provider.dart';
import 'create_business_screen.dart';
import 'widgets/business_logo.dart';

Color _statusColor(String status) => switch (status) {
  'ACTIVE' => const Color(0xFF16A34A),
  'INACTIVE' => const Color(0xFFF59E0B),
  _ => AppTheme.textSecondary,
};

/// Lista de negocios del emprendedor (propios y compartidos) para elegir con cuál trabajar.
class BusinessesScreen extends StatefulWidget {
  const BusinessesScreen({super.key});

  @override
  State<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends State<BusinessesScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchController.clear();
    });
  }

  void _createBusiness() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateBusinessScreen()));

  @override
  Widget build(BuildContext context) {
    final businessProvider = context.watch<BusinessProvider>();
    final currentId = businessProvider.currentBusiness?.id;
    final query = _searchController.text.trim().toLowerCase();
    final businesses = businessProvider.businesses
        .where((b) => query.isEmpty || b.name.toLowerCase().contains(query) || b.category.toLowerCase().contains(query))
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createBusiness,
          icon: const Icon(Icons.add_rounded, size: 26),
          label: const Text('Nuevo negocio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        body: Stack(
          children: [
            // Manchas decorativas del fondo, como en el resto de la app.
            Positioned(top: -90, right: -110, child: _Blob(size: 300, color: AppTheme.primary.withValues(alpha: 0.06))),
            Positioned(
              bottom: -140,
              left: -120,
              child: _Blob(size: 320, color: AppTheme.primary.withValues(alpha: 0.05)),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tus negocios',
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gestiona y haz crecer tus negocios\ndesde un solo lugar.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 1,
                        shadowColor: AppTheme.navy.withValues(alpha: 0.2),
                        child: IconButton(
                          tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar',
                          icon: Icon(
                            _searching ? Icons.close_rounded : Icons.search_rounded,
                            color: AppTheme.textPrimary,
                            size: 28,
                          ),
                          onPressed: _toggleSearch,
                        ),
                      ),
                    ],
                  ),
                  if (_searching) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre o categoría',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (businesses.isEmpty && query.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Ningún negocio coincide con tu búsqueda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  for (final business in businesses)
                    _BusinessCard(
                      business: business,
                      isCurrent: business.id == currentId,
                      onTap: () {
                        context.read<BusinessProvider>().selectBusiness(business);
                        Navigator.of(context).pop();
                      },
                    ),
                  // Con pocos negocios, la pantalla invita a crear otro.
                  if (query.isEmpty && businessProvider.businesses.length <= 1)
                    _Invitation(hasBusinesses: businessProvider.businesses.isNotEmpty),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Business business;
  final bool isCurrent;
  final VoidCallback onTap;

  const _BusinessCard({required this.business, required this.isCurrent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(business.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isCurrent ? AppTheme.primary : Colors.transparent, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: Color(0xFFE6EFFE), shape: BoxShape.circle),
                  child: BusinessLogo(
                    logoUrl: business.logoUrl,
                    fallback: const Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              business.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            const _Tag(label: 'Actual', color: AppTheme.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (business.isShared)
                        Text(
                          'De ${business.ownerName ?? 'otro emprendedor'} · Eres ${business.role.label.toLowerCase()}',
                          style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600),
                        )
                      else
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '${business.category.isEmpty ? '' : business.category[0].toUpperCase() + business.category.substring(1)}'
                                    '  ·  ${Labels.businessStage(business.stage)}  ·  ',
                              ),
                              TextSpan(
                                text: '● ${Labels.status(business.status)}',
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _Invitation extends StatelessWidget {
  final bool hasBusinesses;

  const _Invitation({required this.hasBusinesses});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(80),
                  ),
                ),
                const Icon(Icons.storefront_rounded, size: 96, color: AppTheme.primary),
                Positioned(
                  right: 38,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary,
                      child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Aquí verás todos\ntus negocios!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.25),
          ),
          const SizedBox(height: 10),
          Text(
            hasBusinesses
                ? '¿Tienes otro emprendimiento?\nCréalo y adminístralo desde aquí.'
                : 'Empieza creando tu primer negocio\ny lleva tu emprendimiento al siguiente nivel.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.45),
          ),
        ],
      ),
    );
  }
}
