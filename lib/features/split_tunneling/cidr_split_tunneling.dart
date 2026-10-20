import 'dart:convert';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/split_tunneling/cidr_list.dart';
import 'package:lantern/features/split_tunneling/provider/cidr_notifier.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage(name: 'CidrSplitTunneling')
class CidrSplitTunneling extends ConsumerStatefulWidget {
  const CidrSplitTunneling({super.key});

  @override
  ConsumerState<CidrSplitTunneling> createState() => _CidrSplitTunnelingState();
}

class _CidrSplitTunnelingState extends ConsumerState<CidrSplitTunneling> {
  final _input = TextEditingController();
  String _query = '';
  bool _busy = false;

  static const _fileTypes = XTypeGroup(
    label: 'CIDR lists',
    extensions: ['txt', 'json', 'cidr'],
    uniformTypeIdentifiers: ['public.plain-text', 'public.json'],
    mimeTypes: ['text/plain', 'application/json', 'application/octet-stream'],
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) context.showSnackBarError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(List<String> entries) async {
    final count = await ref
        .read(splitTunnelingCidrsProvider.notifier)
        .add(entries);
    if (!mounted) return;
    _input.clear();
    context.showSnackBar('cidr_added_count'.i18n.fill([count]));
  }

  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: [_fileTypes]);
    if (file == null) return;
    if (await file.length() > CidrList.maxBytes) {
      throw const FormatException('The CIDR file must be 1 MB or smaller.');
    }
    final entries = CidrList.decode(await file.readAsString());
    if (entries.isEmpty) {
      throw FormatException('cidr_empty_import'.i18n);
    }
    await _add(entries);
  }

  Future<void> _export(String format) async {
    final entries = await ref.read(splitTunnelingCidrsProvider.future);
    final json = format == 'json';
    final content = json
        ? CidrList.encodeJson(entries)
        : CidrList.encodeText(entries);
    final name = 'lantern-cidr-excludes.$format';
    final mimeType = json ? 'application/json' : 'text/plain';
    final file = XFile.fromData(
      utf8.encode(content),
      mimeType: mimeType,
      name: name,
    );
    if (Platform.isAndroid || Platform.isIOS) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [name],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      return;
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(
          label: json ? 'JSON' : 'Text',
          extensions: [format],
          uniformTypeIdentifiers: [json ? 'public.json' : 'public.plain-text'],
        ),
      ],
    );
    if (location == null) return;
    await file.saveTo(location.path);
    if (mounted) context.showSnackBar('cidr_exported'.i18n);
  }

  @override
  Widget build(BuildContext context) {
    final cidrs = ref.watch(splitTunnelingCidrsProvider);
    return BaseScreen(
      title: 'cidr_excludes'.i18n,
      body: CustomScrollView(
        key: const Key('split_tunneling.cidr.screen'),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('cidr_excludes_description'.i18n),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('split_tunneling.cidr.input'),
                  controller: _input,
                  enabled: !_busy && cidrs.hasValue,
                  minLines: 1,
                  maxLines: 3,
                  autocorrect: false,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'cidr_input_label'.i18n,
                    hintText: '127.0.0.0/8, ::1/128',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton.icon(
                      key: const Key('split_tunneling.cidr.add'),
                      onPressed: _busy || !cidrs.hasValue
                          ? null
                          : () => _run(() async {
                              final entries = CidrList.decode(_input.text);
                              if (entries.isEmpty) {
                                throw FormatException('cidr_empty_import'.i18n);
                              }
                              await _add(entries);
                            }),
                      icon: const Icon(Icons.add),
                      label: Text('add'.i18n),
                    ),
                    OutlinedButton.icon(
                      key: const Key('split_tunneling.cidr.import'),
                      onPressed: _busy || !cidrs.hasValue
                          ? null
                          : () => _run(_import),
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text('cidr_import'.i18n),
                    ),
                    PopupMenuButton<String>(
                      key: const Key('split_tunneling.cidr.export'),
                      enabled: !_busy && cidrs.hasValue,
                      tooltip: 'cidr_export'.i18n,
                      onSelected: (format) => _run(() => _export(format)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'json', child: Text('JSON')),
                        const PopupMenuItem(value: 'txt', child: Text('TXT')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('cidr_export'.i18n),
                      ),
                    ),
                  ],
                ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('cidr_import_description'.i18n),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('split_tunneling.cidr.search'),
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'cidr_search'.i18n,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          cidrs.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error.toString()),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(splitTunnelingCidrsProvider),
                      child: Text('cidr_retry'.i18n),
                    ),
                  ],
                ),
              ),
            ),
            data: (entries) {
              final shown = entries
                  .where((cidr) => cidr.contains(_query))
                  .toList();
              if (shown.isEmpty) {
                return SliverFillRemaining(
                  child: Center(child: Text('cidr_no_ranges'.i18n)),
                );
              }
              return SliverList.builder(
                key: const Key('split_tunneling.cidr.list'),
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final cidr = shown[index];
                  return ListTile(
                    title: Text(cidr, textDirection: TextDirection.ltr),
                    trailing: IconButton(
                      key: Key('split_tunneling.cidr.remove.$cidr'),
                      tooltip: 'cidr_remove'.i18n,
                      icon: const Icon(Icons.close),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => ref
                                  .read(splitTunnelingCidrsProvider.notifier)
                                  .remove(cidr),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
