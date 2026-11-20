import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'legal.dart';

/// Every package that ships in the app with its licence text, from Flutter's
/// licence registry (generated at build time, so nothing is kept by hand),
/// then [attributions]. All of it is bundled, so it works offline.
class LicencesPage extends StatefulWidget {
  const LicencesPage({super.key});

  @override
  State<LicencesPage> createState() => _LicencesPageState();
}

class _LicencesPageState extends State<LicencesPage> {
  late final Future<Map<String, List<LicenseEntry>>> _packages = _collect();

  /// Each licence file, read once when first opened.
  final _texts = <String, Future<String>>{};

  /// The registry's entries by package name, in alphabetical order. An entry
  /// can cover several packages, and a package can have several entries.
  static Future<Map<String, List<LicenseEntry>>> _collect() async {
    final packages = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        (packages[package] ??= []).add(entry);
      }
    }
    final names = packages.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final name in names) name: packages[name]!};
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(text, style: textTheme.titleMedium),
      ),
    );
    return Scaffold(
      key: licencesPageKey,
      appBar: AppBar(title: Text(l.licencesTitle)),
      body: SafeArea(
        child: FutureBuilder(
          future: _packages,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              heading(l.licencesLibraries),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final MapEntry(key: name, value: entries)
                    in (snapshot.data ?? const {}).entries)
                  _Expandable(
                    title: Text(name),
                    children: [
                      for (final (i, entry) in entries.indexed) ...[
                        if (i > 0) const Divider(),
                        for (final paragraph in entry.paragraphs)
                          _paragraph(paragraph.text, paragraph.indent),
                      ],
                    ],
                  ),
              heading(l.licencesOtherAttributions),
              for (final (:name, :credit, :licenseAsset) in attributions)
                if (licenseAsset == null)
                  ListTile(title: Text(name), subtitle: Text(credit))
                else
                  _Expandable(
                    title: Text(name),
                    subtitle: Text(credit),
                    children: [
                      FutureBuilder(
                        future: _texts.putIfAbsent(
                          licenseAsset,
                          () =>
                              DefaultAssetBundle.of(context)
                                  .loadString(licenseAsset),
                        ),
                        builder: (context, text) =>
                            _paragraph(text.data ?? '', 0),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paragraph(String text, int indent) => Padding(
    padding: EdgeInsetsDirectional.only(
      start: indent > 0 ? 16.0 * indent : 0,
      top: 4,
      bottom: 4,
    ),
    child: Text(
      text,
      textAlign: indent == LicenseParagraph.centeredIndent
          ? TextAlign.center
          : TextAlign.start,
    ),
  );
}

/// A row that opens to show a licence text below it.
class _Expandable extends StatelessWidget {
  const _Expandable({
    required this.title,
    this.subtitle,
    required this.children,
  });

  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: title,
    subtitle: subtitle,
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    children: children,
  );
}
