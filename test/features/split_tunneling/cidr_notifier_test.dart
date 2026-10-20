import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/cidr_list.dart';
import 'package:lantern/features/split_tunneling/provider/cidr_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Service implements LanternService {
  final List<String> cidrs = ['127.0.0.0/8'];
  final List<String> writes = [];
  bool failWrites = false;

  @override
  Future<Either<Failure, List<String>>> getSplitTunnelItems(
    SplitTunnelFilterType type,
  ) async {
    expect(type, SplitTunnelFilterType.ipCidr);
    return right(List.of(cidrs));
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) async {
    expect(type, SplitTunnelFilterType.ipCidr);
    writes.add(value);
    if (failWrites) throw StateError('storage unavailable');
    cidrs.addAll(CidrList.decode(value));
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) async {
    expect(type, SplitTunnelFilterType.ipCidr);
    cidrs.remove(value);
    return right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Service service;
  late ProviderContainer container;
  setUp(() {
    service = _Service();
    container = ProviderContainer(
      overrides: [lanternServiceProvider.overrideWithValue(service)],
    );
  });
  tearDown(() => container.dispose());

  test(
    'merges canonical imports in one backend request without duplicates',
    () async {
      await container.read(splitTunnelingCidrsProvider.future);
      final count = await container
          .read(splitTunnelingCidrsProvider.notifier)
          .add(['127.0.0.1/8', '192.168.1.23/24', '::1/128']);
      expect(count, 2);
      expect(service.writes, ['192.168.1.0/24,::1/128']);
      expect(container.read(splitTunnelingCidrsProvider).requireValue, [
        '127.0.0.0/8',
        '192.168.1.0/24',
        '::1/128',
      ]);
    },
  );

  test('an invalid imported CIDR prevents all writes', () async {
    await container.read(splitTunnelingCidrsProvider.future);
    await expectLater(
      container.read(splitTunnelingCidrsProvider.notifier).add([
        '192.0.2.0/24',
        'invalid',
      ]),
      throwsFormatException,
    );
    expect(service.writes, isEmpty);
    expect(service.cidrs, ['127.0.0.0/8']);
  });

  test('failed write is reported without displaying success state', () async {
    await container.read(splitTunnelingCidrsProvider.future);
    service.failWrites = true;
    await expectLater(
      container.read(splitTunnelingCidrsProvider.notifier).add(['::1/128']),
      throwsStateError,
    );
    expect(container.read(splitTunnelingCidrsProvider).requireValue, [
      '127.0.0.0/8',
    ]);
  });

  test('removal reloads persisted values', () async {
    await container.read(splitTunnelingCidrsProvider.future);
    await container
        .read(splitTunnelingCidrsProvider.notifier)
        .remove('127.0.0.1/8');
    expect(container.read(splitTunnelingCidrsProvider).requireValue, isEmpty);
  });
}
