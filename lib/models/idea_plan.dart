import '../core/utils/decimal.dart';

/// Plan de lanzamiento de un negocio en etapa IDEA. Cada sección se llena desde su propio paso
/// y se guarda completo en `Business.ideaPlan` (JSON) en el backend.
class IdeaPlan {
  final String customerWho;
  final String customerProblem;
  final double? unitCost;
  final double? marginPercent;
  final double? initialInvestment;
  final double? monthlyFixed;
  final double? investmentUnitPrice;
  final double? investmentUnitCost;
  final List<String> channels;
  final String channelsNote;

  const IdeaPlan({
    this.customerWho = '',
    this.customerProblem = '',
    this.unitCost,
    this.marginPercent,
    this.initialInvestment,
    this.monthlyFixed,
    this.investmentUnitPrice,
    this.investmentUnitCost,
    this.channels = const [],
    this.channelsNote = '',
  });

  bool get hasCustomer => customerWho.trim().isNotEmpty && customerProblem.trim().isNotEmpty;
  bool get hasPricing => unitCost != null && marginPercent != null;
  bool get hasInvestment => initialInvestment != null && investmentUnitPrice != null && investmentUnitCost != null;
  bool get hasChannels => channels.isNotEmpty;

  /// Precio sugerido = costo + margen deseado sobre el costo.
  double? get suggestedPrice => hasPricing ? unitCost! * (1 + marginPercent! / 100) : null;

  IdeaPlan copyWith({
    String? customerWho,
    String? customerProblem,
    double? unitCost,
    double? marginPercent,
    double? initialInvestment,
    double? monthlyFixed,
    double? investmentUnitPrice,
    double? investmentUnitCost,
    List<String>? channels,
    String? channelsNote,
  }) {
    return IdeaPlan(
      customerWho: customerWho ?? this.customerWho,
      customerProblem: customerProblem ?? this.customerProblem,
      unitCost: unitCost ?? this.unitCost,
      marginPercent: marginPercent ?? this.marginPercent,
      initialInvestment: initialInvestment ?? this.initialInvestment,
      monthlyFixed: monthlyFixed ?? this.monthlyFixed,
      investmentUnitPrice: investmentUnitPrice ?? this.investmentUnitPrice,
      investmentUnitCost: investmentUnitCost ?? this.investmentUnitCost,
      channels: channels ?? this.channels,
      channelsNote: channelsNote ?? this.channelsNote,
    );
  }

  factory IdeaPlan.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IdeaPlan();
    final customer = json['customer'] as Map<String, dynamic>? ?? {};
    final pricing = json['pricing'] as Map<String, dynamic>? ?? {};
    final investment = json['investment'] as Map<String, dynamic>? ?? {};
    final channels = json['channels'] as Map<String, dynamic>? ?? {};
    double? number(dynamic value) => value == null ? null : parseNum(value).toDouble();

    return IdeaPlan(
      customerWho: customer['who'] as String? ?? '',
      customerProblem: customer['problem'] as String? ?? '',
      unitCost: number(pricing['unitCost']),
      marginPercent: number(pricing['marginPercent']),
      initialInvestment: number(investment['initial']),
      monthlyFixed: number(investment['monthlyFixed']),
      investmentUnitPrice: number(investment['unitPrice']),
      investmentUnitCost: number(investment['unitCost']),
      channels: (channels['selected'] as List<dynamic>? ?? []).cast<String>(),
      channelsNote: channels['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'customer': {'who': customerWho, 'problem': customerProblem},
    'pricing': {'unitCost': ?unitCost, 'marginPercent': ?marginPercent},
    'investment': {
      'initial': ?initialInvestment,
      'monthlyFixed': ?monthlyFixed,
      'unitPrice': ?investmentUnitPrice,
      'unitCost': ?investmentUnitCost,
    },
    'channels': {'selected': channels, 'note': channelsNote},
  };
}
