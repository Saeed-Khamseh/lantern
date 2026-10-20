import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme;
import 'package:lantern/features/split_tunneling/cidr_list.dart';
import 'package:lantern/features/split_tunneling/cidr_split_tunneling.dart';
import 'package:lantern/features/split_tunneling/provider/cidr_notifier.dart';

class _Cidrs extends SplitTunnelingCidrs {
  _Cidrs(this.entries);
  List<String> entries;

  @override
  Future<List<String>> build() async => entries;

  @override
  Future<int> add(Iterable<String> added) async {
    final merged = CidrList.normalizeAll([...entries, ...added]);
    final count = merged.length - entries.length;
    entries = merged;
    state = AsyncData(entries);
    return count;
  }

  @override
  Future<void> remove(String cidr) async {
    entries = entries.where((entry) => entry != cidr).toList();
    state = AsyncData(entries);
  }
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        splitTunnelingCidrsProvider.overrideWith(() => _Cidrs(['127.0.0.0/8'])),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.appTheme(),
          home: const CidrSplitTunneling(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('CIDR controls remain usable in a short window', (tester) async {
    await _pump(tester, const Size(471, 260));
    expect(tester.takeException(), isNull);
    final screen = find.byKey(const Key('split_tunneling.cidr.screen'));
    await tester.drag(screen, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds canonical networks and removes a selected range', (
    tester,
  ) async {
    await _pump(tester, const Size(471, 984));
    await tester.enterText(
      find.byKey(const Key('split_tunneling.cidr.input')),
      '192.168.1.25/24, ::1/128',
    );
    await tester.tap(find.byKey(const Key('split_tunneling.cidr.add')));
    await tester.pumpAndSettle();
    expect(find.text('192.168.1.0/24'), findsOneWidget);
    expect(find.text('::1/128'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('split_tunneling.cidr.remove.::1/128')),
    );
    await tester.pumpAndSettle();
    expect(find.text('::1/128'), findsNothing);
    expect(find.text('127.0.0.0/8'), findsOneWidget);
  });
}
