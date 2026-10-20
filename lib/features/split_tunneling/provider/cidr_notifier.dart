import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/features/split_tunneling/cidr_list.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

final splitTunnelingCidrsProvider =
    AsyncNotifierProvider<SplitTunnelingCidrs, List<String>>(
      SplitTunnelingCidrs.new,
    );

class SplitTunnelingCidrs extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() => _load();

  Future<List<String>> _load() async {
    final result = await ref
        .read(lanternServiceProvider)
        .getSplitTunnelItems(SplitTunnelFilterType.ipCidr);
    return result.match(
      (failure) => throw Exception(failure.localizedErrorMessage),
      CidrList.normalizeAll,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<int> add(Iterable<String> entries) async {
    final current = await _load();
    final added = CidrList.normalizeAll(
      entries,
    ).where((entry) => !current.contains(entry)).toList();
    if (current.length + added.length > CidrList.maxEntries) {
      throw const FormatException('A list can contain at most 10,000 CIDRs.');
    }
    if (added.isEmpty) return 0;
    final result = await ref
        .read(lanternServiceProvider)
        .addSplitTunnelItem(SplitTunnelFilterType.ipCidr, added.join(','));
    result.match(
      (failure) => throw Exception(failure.localizedErrorMessage),
      (_) {},
    );
    state = AsyncData(await _load());
    return added.length;
  }

  Future<void> remove(String cidr) async {
    final result = await ref
        .read(lanternServiceProvider)
        .removeSplitTunnelItem(
          SplitTunnelFilterType.ipCidr,
          CidrList.normalize(cidr),
        );
    result.match(
      (failure) => throw Exception(failure.localizedErrorMessage),
      (_) {},
    );
    state = AsyncData(await _load());
  }
}
