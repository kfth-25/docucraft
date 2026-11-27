// DocuCraft CRDT — Fractional Index
// Untuk mengurutkan movable list dan tree tanpa konflik
// Port dari loro-js: fractional-index.ts

import 'dart:math';
import 'dart:typed_data';

/// Fractional Index — generates orderable strings between any two existing indices
/// Uses base-36 (0-9, a-z) for compact representation
class FractionalIndex {
  static const String _digits = '0123456789abcdefghijklmnopqrstuvwxyz';
  static const int _base = 36;
  static const int _minLength = 4;
  static const String _minChar = '0';
  static const String _maxChar = 'z';

  /// Generate a fractional index between two existing indices
  /// Returns null if no space available (should rarely happen with base-36)
  static String? between(String? left, String? right) {
    // Normalize: empty string = beginning, null = end
    final l = left ?? '';
    final r = right ?? _maxChar * (max(l.length, _minLength) + 2);

    // Ensure left < right
    if (l.compareTo(r) >= 0) return null;

    // Find common prefix
    int commonLen = 0;
    final minLen = min(l.length, r.length);
    while (commonLen < minLen && l[commonLen] == r[commonLen]) {
      commonLen++;
    }

    // If left is prefix of right, we can append to left
    if (commonLen == l.length && l.length < r.length) {
      return l + _digits[_base ~/ 2]; // Middle character
    }

    // Work with the differing suffix
    final leftSuffix = l.substring(commonLen);
    final rightSuffix = r.substring(commonLen);

    // Try to find a middle string
    final result = _findMiddle(leftSuffix, rightSuffix);
    if (result == null) return null;

    return l.substring(0, commonLen) + result;
  }

  /// Find a string lexicographically between two strings of same length
  static String? _findMiddle(String left, String right) {
    if (left.compareTo(right) >= 0) return null;

    // Convert to arrays of digit values
    final leftDigits = left.split('').map(_charToVal).toList();
    final rightDigits = right.split('').map(_charToVal).toList();

    // Pad shorter with zeros
    final maxLen = max(leftDigits.length, rightDigits.length);
    while (leftDigits.length < maxLen) leftDigits.add(0);
    while (rightDigits.length < maxLen) rightDigits.add(0);

    // Add 1 to left (like adding 1 to a number)
    final middleDigits = <int>[];
    int carry = 1;
    for (int i = maxLen - 1; i >= 0; i--) {
      int sum = leftDigits[i] + carry;
      carry = sum ~/ _base;
      middleDigits.insert(0, sum % _base);
    }
    if (carry > 0) middleDigits.insert(0, carry);

    // Convert back to string
    String result = middleDigits.map(_valToChar).join('');

    // Verify it's strictly between
    if (result.compareTo(left) > 0 && result.compareTo(right) < 0) {
      // Trim trailing zeros (min chars)
      return result.replaceAll(RegExp('^0+'), '');
    }

    // If no space, try longer strings
    return _findMiddleWithPadding(left, right);
  }

  /// Try with extra padding to find space
  static String? _findMiddleWithPadding(String left, String right) {
    // Add padding to left and try again
    for (int extra = 1; extra <= 4; extra++) {
      final paddedLeft = left + '0' * extra;
      final paddedRight = right + 'z' * extra;
      final result = _findMiddle(paddedLeft, paddedRight);
      if (result != null) return result;
    }
    return null;
  }

  /// Generate initial index for first item
  static String initial() => 'a'; // Middle of range

  /// Generate index for append at end
  static String after(String last) {
    if (last.isEmpty) return initial();
    // Increment last character or append
    final chars = last.split('');
    for (int i = chars.length - 1; i >= 0; i--) {
      final val = _charToVal(chars[i]);
      if (val < _base - 1) {
        chars[i] = _valToChar(val + 1);
        return chars.join('');
      }
      chars[i] = _minChar;
    }
    return chars.join('') + _minChar;
  }

  /// Generate index for prepend at beginning
  static String before(String first) {
    if (first.isEmpty) return initial();
    final chars = first.split('');
    for (int i = chars.length - 1; i >= 0; i--) {
      final val = _charToVal(chars[i]);
      if (val > 0) {
        chars[i] = _valToChar(val - 1);
        return chars.join('');
      }
      chars[i] = _maxChar;
    }
    return _minChar + chars.join('');
  }

  /// Compare two fractional indices
  static int compare(String a, String b) => a.compareTo(b);

  /// Check if index is valid
  static bool isValid(String index) {
    return RegExp(r'^[0-9a-z]+$').hasMatch(index);
  }

  // ─── Helpers ───

  static int _charToVal(String c) => _digits.indexOf(c);
  static String _valToChar(int v) => _digits[v % _base];

  /// Generate a random index in the middle of range
  static String random() {
    final rand = Random.secure();
    final length = _minLength + rand.nextInt(4);
    return String.fromCharCodes(
      List.generate(length, (_) => _digits.codeUnitAt(rand.nextInt(_base))),
    );
  }

  /// Normalize index (remove leading zeros, ensure minimum length)
  static String normalize(String index) {
    final normalized = index.replaceAll(RegExp('^0+'), '');
    if (normalized.length < _minLength) {
      return normalized.padLeft(_minLength, '0');
    }
    return normalized;
  }
}

/// Fractional Index for Tree — hierarchical ordering
class TreeFractionalIndex {
  /// Create child index under parent
  static String childOf(String parent, {String? afterSibling}) {
    if (afterSibling == null) {
      return parent + '.a'; // First child
    }
    return FractionalIndex.between(afterSibling, null) ?? afterSibling + '.a';
  }

  /// Get parent index from child
  static String? parentOf(String child) {
    final lastDot = child.lastIndexOf('.');
    if (lastDot <= 0) return null;
    return child.substring(0, lastDot);
  }

  /// Get depth of index
  static int depth(String index) => index.split('.').length;

  /// Compare tree indices (depth-first order)
  static int compare(String a, String b) {
    final aParts = a.split('.');
    final bParts = b.split('.');
    final minLen = min(aParts.length, bParts.length);

    for (int i = 0; i < minLen; i++) {
      final cmp = FractionalIndex.compare(aParts[i], bParts[i]);
      if (cmp != 0) return cmp;
    }
    // Shorter (parent) comes before longer (child)
    return aParts.length.compareTo(bParts.length);
  }

  /// Check if a is ancestor of b
  static bool isAncestor(String ancestor, String descendant) {
    return descendant.startsWith(ancestor + '.');
  }

  /// Get next sibling index
  static String? nextSibling(String index) {
    final parent = parentOf(index);
    if (parent == null) return FractionalIndex.after(index);
    return FractionalIndex.after(index);
  }

  /// Get previous sibling index
  static String? prevSibling(String index) {
    return FractionalIndex.before(index);
  }
}