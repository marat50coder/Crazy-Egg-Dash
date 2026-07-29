// ════════════════════════════════════════════════════════════════════════
// Credential encoder for the gray flow (Crazy Egg Dash).
//
// Usage:
//   dart run tool/encode_era_values.dart
//
// 1. Keep the cipher below IN SYNC with lib/hatchway/core/feather_codec.dart
//    (same `_nestSalt`, same stream + positional shift). If you change the
//    salt or the algorithm there, mirror it here and re-run.
// 2. Paste the printed byte arrays into
//    lib/hatchway/config/era_hatch_config.dart.
// 3. The VERIFY block must round-trip EACH value byte-for-byte, otherwise a
//    stray/missing byte silently corrupts the URL (gray_flow_lessons.md §12).
//
// ⚠️ Never hand-edit the byte arrays. Always regenerate here.
// ════════════════════════════════════════════════════════════════════════
// ignore_for_file: avoid_print
import 'dart:typed_data';

// MUST match lib/hatchway/core/feather_codec.dart exactly.
const List<int> _nestSalt = <int>[
  0x63, 0x45, 0x64, 0x23, 0x72, 0x75, 0x73, 0x68, 0x2A, 0x32, 0x36, 0x2E, 0x6B,
];

// ── Plaintext values (source of truth) ─────────────────────────────────
const Map<String, String> _values = <String, String>{
  'endpoint': 'https://crazyeggdash.com/config.php',
  'privacy': 'https://crazyeggdash.com/privacy-policy.html',
  'support': 'https://crazyeggdash.com/support.html',
  'appsFlyerKey': 'oPXjEGp3vCP3fDVGf8Xm5Y',
  'firebaseProject': '239730018066',
  'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
  'webkit': '605.1.15',
  'safari': '18.5',
  'safariTail': '604.1',
  'oneLinkHost': 'crazyeggdash.onelink.me',
};

Uint8List _buildFeatherStream(int length) {
  final state = List<int>.generate(256, (index) => index);
  var cursor = 0;
  for (var index = 0; index < state.length; index++) {
    cursor =
        (cursor + state[index] + _nestSalt[index % _nestSalt.length]) & 0xff;
    final swap = state[index];
    state[index] = state[cursor];
    state[cursor] = swap;
  }
  final result = Uint8List(length);
  var left = 0;
  var right = 0;
  for (var index = 0; index < length; index++) {
    left = (left + 1) & 0xff;
    right = (right + state[left] + index) & 0xff;
    final swap = state[left];
    state[left] = state[right];
    state[right] = swap;
    result[index] = state[(state[left] + state[right]) & 0xff];
  }
  return result;
}

List<int> _fold(String plain) {
  final bytes = plain.codeUnits;
  final stream = _buildFeatherStream(bytes.length);
  final out = List<int>.filled(bytes.length, 0);
  for (var index = 0; index < bytes.length; index++) {
    out[index] = (bytes[index] + stream[index] + (index * 29)) & 0xff;
  }
  return out;
}

String _unfold(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _buildFeatherStream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (encoded[index] - stream[index] - (index * 29)) & 0xff;
  }
  return String.fromCharCodes(plain);
}

void main() {
  print('// ── Encoded byte arrays (paste into era_hatch_config.dart) ──');
  _values.forEach((name, plain) {
    final encoded = _fold(plain);
    final formatted = encoded.join(', ');
    print('  // $name — $plain');
    print('  static const List<int> _$name = <int>[$formatted];');
  });

  print('\n// ── VERIFY (must match plaintext exactly) ──');
  var allOk = true;
  _values.forEach((name, plain) {
    final roundTrip = _unfold(_fold(plain));
    final ok = roundTrip == plain;
    allOk = allOk && ok;
    print('${ok ? 'OK ' : 'FAIL'}  $name => "$roundTrip"');
  });
  print(allOk ? '\nALL ROUND-TRIPS OK' : '\n!!! ROUND-TRIP FAILURE !!!');
}
