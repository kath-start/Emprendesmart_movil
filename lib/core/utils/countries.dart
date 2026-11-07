/// Países que se pueden elegir en el perfil, con su código ISO (para la bandera).
const countryCodes = {
  'Perú': 'PE',
  'Argentina': 'AR',
  'Bolivia': 'BO',
  'Brasil': 'BR',
  'Chile': 'CL',
  'Colombia': 'CO',
  'Costa Rica': 'CR',
  'Cuba': 'CU',
  'Ecuador': 'EC',
  'El Salvador': 'SV',
  'España': 'ES',
  'Estados Unidos': 'US',
  'Guatemala': 'GT',
  'Honduras': 'HN',
  'México': 'MX',
  'Nicaragua': 'NI',
  'Panamá': 'PA',
  'Paraguay': 'PY',
  'Puerto Rico': 'PR',
  'República Dominicana': 'DO',
  'Uruguay': 'UY',
  'Venezuela': 'VE',
};

/// Código telefónico internacional de cada país de [countryCodes].
const countryDialCodes = {
  'Perú': '+51',
  'Argentina': '+54',
  'Bolivia': '+591',
  'Brasil': '+55',
  'Chile': '+56',
  'Colombia': '+57',
  'Costa Rica': '+506',
  'Cuba': '+53',
  'Ecuador': '+593',
  'El Salvador': '+503',
  'España': '+34',
  'Estados Unidos': '+1',
  'Guatemala': '+502',
  'Honduras': '+504',
  'México': '+52',
  'Nicaragua': '+505',
  'Panamá': '+507',
  'Paraguay': '+595',
  'Puerto Rico': '+1',
  'República Dominicana': '+1',
  'Uruguay': '+598',
  'Venezuela': '+58',
};

/// Separa "+51 929020723" en país y número. Si varios países comparten el código (+1),
/// se prefiere [preferredCountry]. Sin código reconocible, el país es [preferredCountry] o Perú.
({String country, String number}) splitPhone(String? phone, {String? preferredCountry}) {
  final fallback = countryDialCodes.containsKey(preferredCountry) ? preferredCountry! : 'Perú';
  final raw = (phone ?? '').trim();
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (!raw.startsWith('+')) return (country: fallback, number: digits);

  String? best;
  for (final entry in countryDialCodes.entries) {
    final code = entry.value.substring(1);
    if (!digits.startsWith(code)) continue;
    final bestLength = best == null ? 0 : countryDialCodes[best]!.length;
    final better =
        entry.value.length > bestLength || (entry.value.length == bestLength && entry.key == preferredCountry);
    if (better) best = entry.key;
  }
  if (best == null) return (country: fallback, number: digits);
  return (country: best, number: digits.substring(countryDialCodes[best]!.length - 1));
}

/// "929020723" → "929 020 723".
String groupPhoneDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Bandera en emoji del país ("Perú" → 🇵🇪); null si no está en la lista.
String? countryFlag(String? country) {
  final code = countryCodes[country];
  if (code == null) return null;
  // Cada letra del código se convierte en su "indicador regional" Unicode; juntos forman la bandera.
  return String.fromCharCodes(code.codeUnits.map((unit) => unit - 0x41 + 0x1F1E6));
}
