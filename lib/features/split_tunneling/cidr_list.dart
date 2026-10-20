import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class CidrList {
  static const maxBytes = 1024 * 1024;
  static const maxEntries = 10000;

  static String normalize(String input) {
    final parts = input.trim().split('/');
    if (parts.length != 2 ||
        parts.first.contains('%') ||
        !RegExp(r'^[0-9]+$').hasMatch(parts.last)) {
      throw FormatException('Invalid CIDR: $input');
    }
    final address = InternetAddress.tryParse(parts.first);
    final prefix = int.tryParse(parts.last);
    if (address == null || prefix == null) {
      throw FormatException('Invalid CIDR: $input');
    }
    final bytes = Uint8List.fromList(address.rawAddress);
    if (prefix < 0 || prefix > bytes.length * 8) {
      throw FormatException('Invalid prefix length: $input');
    }
    for (var i = 0; i < bytes.length; i++) {
      final remaining = prefix - i * 8;
      if (remaining <= 0) {
        bytes[i] = 0;
      } else if (remaining < 8) {
        bytes[i] &= (0xff << (8 - remaining)) & 0xff;
      }
    }
    return '${InternetAddress.fromRawAddress(bytes).address}/$prefix';
  }

  static List<String> normalizeAll(Iterable<String> entries) {
    final canonical = <String>{};
    var count = 0;
    for (final entry in entries) {
      if (++count > maxEntries) {
        throw const FormatException('A list can contain at most 10,000 CIDRs.');
      }
      canonical.add(normalize(entry));
    }
    return canonical.toList()..sort();
  }

  static List<String> decode(String input) {
    if (utf8.encode(input).length > maxBytes) {
      throw const FormatException('The CIDR file must be 1 MB or smaller.');
    }
    final text = input.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (text.isEmpty) return [];
    if (text.startsWith('{') || text.startsWith('[')) {
      final decoded = jsonDecode(text);
      final Object? entries;
      if (decoded is List) {
        entries = decoded;
      } else if (decoded is Map &&
          decoded['version'] == 1 &&
          decoded['type'] == 'lantern-cidr-excludes') {
        entries = decoded['cidrs'];
      } else {
        throw const FormatException('Unsupported CIDR file format or version.');
      }
      if (entries is! List || entries.any((entry) => entry is! String)) {
        throw const FormatException('The CIDR list must contain only strings.');
      }
      return normalizeAll(entries.cast<String>());
    }
    final entries = <String>[];
    final lines = const LineSplitter().convert(text);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].split('#').first.trim();
      if (line.isEmpty) continue;
      for (final entry in line.split(',')) {
        try {
          entries.add(normalize(entry));
        } on FormatException catch (error) {
          throw FormatException('Line ${i + 1}: ${error.message}');
        }
      }
    }
    return normalizeAll(entries);
  }

  static String encodeJson(Iterable<String> entries) {
    return '${const JsonEncoder.withIndent('  ').convert({'version': 1, 'type': 'lantern-cidr-excludes', 'cidrs': normalizeAll(entries)})}\n';
  }

  static String encodeText(Iterable<String> entries) {
    final cidrs = normalizeAll(entries);
    return cidrs.isEmpty ? '' : '${cidrs.join('\n')}\n';
  }
}

