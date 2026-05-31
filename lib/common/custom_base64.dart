import 'dart:convert';
import 'dart:typed_data';

class CustomBase64 {
  // Standard base64 alphabet — replace this string to use a custom encoding table.
  static const String alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  // URL-safe alternatives that map to positions 62 and 63.
  static const String altChar62 = '-';
  static const String altChar63 = '_';

  static Uint8List decode(String input) {
    final clean = input.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return Uint8List(0);

    final lookup = _buildLookup();
    final output = <int>[];
    var buffer = 0;
    var bits = 0;

    for (final ch in clean.codeUnits) {
      if (ch == 0x3D) break; // '=' padding
      final value = lookup[ch];
      if (value == null) {
        throw FormatException('Invalid character in custom base64: ${String.fromCharCode(ch)}');
      }
      buffer = (buffer << 6) | value;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        output.add((buffer >> bits) & 0xFF);
      }
    }

    return Uint8List.fromList(output);
  }

  static String decodeToString(String input) => utf8.decode(decode(input));

  static Map<int, int> _buildLookup() {
    final map = <int, int>{};
    for (var i = 0; i < alphabet.length; i++) {
      map[alphabet.codeUnitAt(i)] = i;
    }
    // Map URL-safe alternatives to positions 62 and 63.
    map[altChar62.codeUnitAt(0)] = 62;
    map[altChar63.codeUnitAt(0)] = 63;
    return map;
  }
}
