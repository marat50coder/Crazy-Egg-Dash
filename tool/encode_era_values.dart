// ════════════════════════════════════════════════════════════════════════
// Credential encoder for the gray flow (Crazy Egg Dash).
//
// Usage:
//   dart run tool/encode_era_values.dart
//
// 1. Keep the cipher below IN SYNC with lib/hatchway/core/feather_codec.dart
//    (same `_shardPepper`, same FNV-1a seed + LCG stream + position
//    scramble). If you change any step there, mirror it here and re-run.
// 2. Paste the printed byte arrays into
//    lib/hatchway/config/era_hatch_config.dart.
// 3. The VERIFY block must round-trip EACH value byte-for-byte, otherwise
//    a stray/missing byte silently corrupts the URL.
//
// Never hand-edit the byte arrays. Always regenerate here.
// ════════════════════════════════════════════════════════════════════════
// ignore_for_file: avoid_print
import 'dart:typed_data';

// MUST match lib/hatchway/core/feather_codec.dart exactly.
const List<int> _shardPepper = <int>[
  0x9C, 0x51, 0x2D, 0x84, 0x37, 0xE2, 0x6F, 0x0B, 0xA6, 0x71, 0x18, 0xCD, 0x5A,
  0xF3, 0x22,
];

const int _fnvPrime = 0x01000193;
const int _fnvOffset = 0x811C9DC5;
const int _lcgMul = 1664525;
const int _lcgAdd = 1013904223;

// ── Plaintext values (source of truth) ─────────────────────────────────
const Map<String, String> _values = <String, String>{
  'endpoint': 'https://crazyeggdash.com/config.php',
  'privacy': 'https://crazyeggdash.com/privacy-policy.html',
  'support': 'https://crazyeggdash.com/support.html',
  'appsFlyerKey': 'oPXjEGp3vCP3fDVGf8Xm5Y',
  'firebaseProject': '239730018066',
  'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
  'webkit': '605.1.15',
  'safari': '18.7',
  'safariTail': '604.1',
  'oneLinkHost': 'crazyeggdash.onelink.me',
};

int _brewLcgSeed(int payloadSize) {
  var acc = _fnvOffset;
  for (var i = 0; i < _shardPepper.length; i++) {
    acc = ((acc ^ _shardPepper[i]) * _fnvPrime) & 0xFFFFFFFF;
  }
  acc = ((acc ^ (payloadSize & 0xFF)) * _fnvPrime) & 0xFFFFFFFF;
  acc = ((acc ^ ((payloadSize >> 8) & 0xFF)) * _fnvPrime) & 0xFFFFFFFF;
  acc = ((acc ^ ((payloadSize >> 16) & 0xFF)) * _fnvPrime) & 0xFFFFFFFF;
  return acc;
}

Uint8List _drawShellKeystream(int size) {
  var state = _brewLcgSeed(size);
  final keystream = Uint8List(size);
  var i = 0;
  while (i < size) {
    state = (state * _lcgMul + _lcgAdd) & 0xFFFFFFFF;
    keystream[i] = (state >> 17) & 0xFF;
    i++;
  }
  return keystream;
}

int _positionScramble(int index) {
  final quad = (index * index) & 0xFF;
  return (((index * 47) ^ 0xA5) + quad) & 0xFF;
}

List<int> _seal(String plain) {
  final bytes = plain.codeUnits;
  final keystream = _drawShellKeystream(bytes.length);
  final out = List<int>.filled(bytes.length, 0);
  for (var i = 0; i < bytes.length; i++) {
    final xored = bytes[i] ^ keystream[i];
    out[i] = (xored + _positionScramble(i)) & 0xFF;
  }
  return out;
}

String _crack(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final keystream = _drawShellKeystream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    final subtracted = (encoded[i] - _positionScramble(i)) & 0xFF;
    plain[i] = subtracted ^ keystream[i];
  }
  return String.fromCharCodes(plain);
}

void main() {
  print('// ── Encoded byte arrays (paste into era_hatch_config.dart) ──');
  _values.forEach((name, plain) {
    final encoded = _seal(plain);
    final formatted = encoded.join(', ');
    print('  // $name — $plain');
    print('  static const List<int> _$name = <int>[$formatted];');
  });

  print('\n// ── VERIFY (must match plaintext exactly) ──');
  var allOk = true;
  _values.forEach((name, plain) {
    final roundTrip = _crack(_seal(plain));
    final ok = roundTrip == plain;
    allOk = allOk && ok;
    print('${ok ? 'OK ' : 'FAIL'}  $name => "$roundTrip"');
  });
  print(allOk ? '\nALL ROUND-TRIPS OK' : '\n!!! ROUND-TRIP FAILURE !!!');
}
