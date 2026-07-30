import 'dart:typed_data';

// ═══════════════════════════════════════════════════════════════════════
// Eggshell obfuscator — FNV-1a seeded LCG keystream + XOR + positional
// mask. Distinct family from any KSA/PRGA-based sibling app.
// If you touch _shardPepper OR any step below, mirror the change in
// tool/encode_era_values.dart and regenerate ALL byte arrays in
// hatchway/config/era_hatch_config.dart.
// ═══════════════════════════════════════════════════════════════════════

const List<int> _shardPepper = <int>[
  0x9C, 0x51, 0x2D, 0x84, 0x37, 0xE2, 0x6F, 0x0B, 0xA6, 0x71, 0x18, 0xCD, 0x5A,
  0xF3, 0x22,
];

const int _fnvPrime = 0x01000193;
const int _fnvOffset = 0x811C9DC5;
const int _lcgMul = 1664525;
const int _lcgAdd = 1013904223;

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

String crackShell(List<int> encoded) {
  final size = encoded.length;
  if (size == 0) return '';
  final keystream = _drawShellKeystream(size);
  final plain = Uint8List(size);
  for (var i = 0; i < size; i++) {
    final subtracted = (encoded[i] - _positionScramble(i)) & 0xFF;
    plain[i] = subtracted ^ keystream[i];
  }
  return String.fromCharCodes(plain);
}
