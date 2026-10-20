import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/split_tunneling/cidr_list.dart';

void main() {
  test('canonicalizes IPv4 and IPv6 networks without DNS', () {
    expect(CidrList.normalize('192.168.1.25/24'), '192.168.1.0/24');
    expect(CidrList.normalize('127.0.0.1/32'), '127.0.0.1/32');
    expect(CidrList.normalize('2001:0DB8::abcd/32'), '2001:db8::/32');
    expect(CidrList.normalize('::1/128'), '::1/128');
    expect(CidrList.normalize('192.0.2.1/0'), '0.0.0.0/0');
    expect(CidrList.normalize('2001:db8::1/0'), '::/0');
    expect(CidrList.normalize('192.0.2.255/25'), '192.0.2.128/25');
  });

  test('rejects malformed addresses, masks, zones, URLs and hostnames', () {
    for (final input in [
      'localhost/32',
      '127.0.0.1',
      '127.0.0.1/33',
      '::1/129',
      'fe80::1%eth0/64',
      'http://127.0.0.1/32',
      '1.2.3.999/24',
      '127.0.0.1/-1',
      '127.0.0.1/1.5',
      '127.0.0.1/+8',
      '127.0.0.1:4200/32',
      '',
    ]) {
      expect(
        () => CidrList.normalize(input),
        throwsFormatException,
        reason: input,
      );
    }
  });

  test('text import supports BOM, CRLF, comments, commas and duplicates', () {
    expect(
      CidrList.decode(
        '\uFEFF# Local\r\n127.0.0.1/8, ::1/128\r\n127.1.2.3/8 # duplicate',
      ),
      ['127.0.0.0/8', '::1/128'],
    );
  });

  test('invalid text reports the offending line', () {
    expect(
      () => CidrList.decode('# comment\n127.0.0.0/8\ninvalid'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Line 3'),
        ),
      ),
    );
  });

  test('JSON and text exports round trip deterministically', () {
    final entries = ['::1/128', '192.168.1.42/24', '192.168.1.0/24'];
    final expected = ['192.168.1.0/24', '::1/128'];
    expect(CidrList.decode(CidrList.encodeJson(entries)), expected);
    expect(CidrList.decode(CidrList.encodeText(entries)), expected);
    expect(CidrList.decode(jsonEncode(entries)), expected);
    expect(CidrList.decode(CidrList.encodeJson([])), isEmpty);
  });

  test('rejects unsupported JSON and non-string entries', () {
    for (final input in [
      '{"version":2,"type":"lantern-cidr-excludes","cidrs":[]}',
      '{"version":1,"type":"different","cidrs":[]}',
      '[123]',
      '{"version":1,"type":"lantern-cidr-excludes","cidrs":null}',
      '["127.0.0.0/8", "bad"]',
      '{invalid',
    ]) {
      expect(
        () => CidrList.decode(input),
        throwsFormatException,
        reason: input,
      );
    }
  });

  test('limits bytes and entries before changing any settings', () {
    expect(
      () => CidrList.decode(' ' * (CidrList.maxBytes + 1)),
      throwsFormatException,
    );
    expect(
      () => CidrList.normalizeAll(
        List.filled(CidrList.maxEntries + 1, '127.0.0.0/8'),
      ),
      throwsFormatException,
    );
  });
}

