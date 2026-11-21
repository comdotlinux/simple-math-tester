import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'legal.dart';
import 'math_tester_model.dart';
import 'operations.dart';
import 'progress.dart';
import 'report.dart';

/// The grown-up check's numbers with their words in the app language. The
/// check is a speed bump for children who cannot yet read number words, not
/// security: anyone who reads the words passes it.
List<(int, String)> checkNumbers(AppLocalizations l) => [
  (17, l.checkNumber17),
  (24, l.checkNumber24),
  (36, l.checkNumber36),
  (42, l.checkNumber42),
  (53, l.checkNumber53),
  (58, l.checkNumber58),
  (61, l.checkNumber61),
  (75, l.checkNumber75),
  (79, l.checkNumber79),
  (84, l.checkNumber84),
  (93, l.checkNumber93),
  (98, l.checkNumber98),
];

/// The question code as the report sends it and as the issue's title names
/// it: `algebra missingAddend [3, 4] L2`.
String reportCode(SuspectQuestion code) =>
    '${code.kind} ${code.variant} [${code.params.join(', ')}] L${code.level}';

/// The flag on a question card and on a history entry: marks the question
/// on this device (which sends nothing) and opens the report dialog. Filled
/// once the question is marked.
class ReportFlag extends StatelessWidget {
  const ReportFlag({super.key, required this.problem, this.color});

  final Problem problem;

  /// The icon's colour on a coloured band; null takes the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mark = context.select((MathTesterModel m) => m.suspectOf(problem));
    return IconButton(
      tooltip: mark == null
          ? l.reportFlag
          : mark.sent
          ? l.reportFlagSent
          : l.reportFlagMarked,
      color: color,
      icon: Icon(mark == null ? Icons.outlined_flag : Icons.flag),
      onPressed: () {
        context.read<MathTesterModel>().markSuspect(problem);
        showReportDialog(context, problem: problem);
      },
    );
  }
}

/// Asks a grown-up first and lists exactly what is sent, then a pick-list,
/// then the grown-up check, then one request; nothing is sent before the
/// check passes. [problem] is the marked question; without one it is a
/// problem report from the settings.
Future<void> showReportDialog(BuildContext context, {Problem? problem}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ReportDialog(problem: problem),
    );

enum _Step { ask, pick, check, sending, done }

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({this.problem});

  final Problem? problem;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _random = Random();
  final _typed = TextEditingController();
  var _step = _Step.ask;
  String? _choice;
  int _number = 0;
  bool _wrong = false;
  ReportOutcome? _outcome;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// A new number for each check, never the one shown before.
  void _newNumber() {
    final numbers = checkNumbers(AppLocalizations.of(context));
    int next;
    do {
      next = numbers[_random.nextInt(numbers.length)].$1;
    } while (next == _number);
    _number = next;
    _typed.clear();
  }

  void _toCheck() => setState(() {
    _step = _Step.check;
    _wrong = false;
    _newNumber();
  });

  void _check() {
    if (int.tryParse(_typed.text.trim()) == _number) {
      _send();
    } else {
      setState(() {
        _wrong = true;
        _newNumber();
      });
    }
  }

  Future<void> _send() async {
    final model = context.read<MathTesterModel>();
    final locale = AppLocalizations.of(context).localeName;
    setState(() => _step = _Step.sending);
    final outcome = switch (widget.problem) {
      final problem? => await model.sendQuestionReport(
        problem,
        _choice!,
        locale,
      ),
      null => await model.sendProblemReport(_choice!, locale),
    };
    if (!mounted) return;
    setState(() {
      _step = _Step.done;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final problem = widget.problem;
    final mark = problem == null
        ? null
        : context.select((MathTesterModel m) => m.suspectOf(problem));
    final code = problem == null ? null : mark ?? SuspectQuestion.of(problem)!;
    void close() => Navigator.pop(context);
    Widget button(Key key, String label, VoidCallback? onPressed) =>
        TextButton(key: key, onPressed: onPressed, child: Text(label));
    Widget next(Key key, String label, VoidCallback? onPressed) =>
        FilledButton(key: key, onPressed: onPressed, child: Text(label));
    final cancel = button(reportCancelKey, material.cancelButtonLabel, close);
    final closeButton = button(
      reportCloseKey,
      material.closeButtonLabel,
      close,
    );

    final (
      String? title,
      List<Widget> content,
      List<Widget> actions,
    ) = switch (_step) {
      _Step.ask when mark?.sent ?? false => (
        l.reportAskTitle,
        [Text(l.reportAlreadySent)],
        [
          button(reportRemoveMarkKey, l.reportRemoveMark, () {
            context.read<MathTesterModel>().unmarkSuspect(problem!);
            close();
          }),
          closeButton,
        ],
      ),
      _Step.ask => (
        l.reportAskTitle,
        [
          if (mark != null) Text(l.reportMarkedNote),
          Text(l.reportAskBody),
          Text(l.reportSendsHeading, style: textTheme.titleSmall),
          for (final item in [
            if (code != null) ...[
              l.reportSendsQuestion(reportCode(code)),
              l.reportSendsReason,
            ] else
              l.reportSendsCategory,
            l.reportSendsApp(appVersion, reportPlatform, l.localeName),
            l.reportSendsNothingElse,
          ])
            Text('• $item'),
        ],
        [
          if (problem != null) ...[
            button(reportRemoveMarkKey, l.reportRemoveMark, () {
              context.read<MathTesterModel>().unmarkSuspect(problem);
              close();
            }),
            button(reportNotNowKey, l.reportNotNow, close),
          ] else
            cancel,
          next(
            reportContinueKey,
            l.reportContinue,
            () => setState(() => _step = _Step.pick),
          ),
        ],
      ),
      _Step.pick => (
        problem == null ? l.reportCategoryTitle : l.reportReasonTitle,
        [
          for (final (name, label)
              in problem == null ? _categories(l) : _reasons(l, problem.kind))
            ListTile(
              key: reportOptionKey(name),
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              selected: name == _choice,
              trailing: Icon(
                name == _choice
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => setState(() => _choice = name),
            ),
        ],
        [
          button(
            reportBackKey,
            material.backButtonTooltip,
            () => setState(() => _step = _Step.ask),
          ),
          next(
            reportContinueKey,
            l.reportContinue,
            _choice == null ? null : _toCheck,
          ),
        ],
      ),
      _Step.check => (
        l.reportCheckTitle,
        [
          if (_wrong)
            Text(
              l.reportCheckWrong,
              key: reportCheckWrongKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Text(l.reportCheckPrompt),
          Text(
            checkNumbers(l).firstWhere((n) => n.$1 == _number).$2,
            key: reportCheckWordKey,
            style: textTheme.headlineSmall,
          ),
          TextField(
            key: reportCheckFieldKey,
            controller: _typed,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l.reportCheckField),
            onSubmitted: (_) => _check(),
          ),
        ],
        [cancel, next(reportSendKey, l.reportSend, _check)],
      ),
      _Step.sending => (
        null,
        [
          Row(
            spacing: 16,
            children: [
              const CircularProgressIndicator(),
              Expanded(child: Text(l.reportSending)),
            ],
          ),
        ],
        const <Widget>[],
      ),
      _Step.done when _outcome == ReportOutcome.sent => (
        null,
        [Text(l.reportThanks, key: reportResultKey)],
        [closeButton],
      ),
      _Step.done => (
        null,
        [
          Text(
            problem == null ? l.reportFailedProblem : l.reportFailedQuestion,
            key: reportResultKey,
          ),
        ],
        [closeButton, next(reportTryAgainKey, l.reportTryAgain, _toCheck)],
      ),
    };
    return AlertDialog(
      key: reportDialogKey,
      scrollable: true,
      title: title == null ? null : Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: content,
      ),
      actions: actions,
    );
  }

  static List<(String, String)> _reasons(
    AppLocalizations l,
    OperationType kind,
  ) => [
    for (final name in questionReasons(kind.name))
      (
        name,
        switch (name) {
          'wrongAnswer' => l.reportReasonWrongAnswer,
          'unclearQuestion' => l.reportReasonUnclearQuestion,
          'wrongHint' => l.reportReasonWrongHint,
          _ => l.reportReasonWrongDrawing,
        },
      ),
  ];

  static List<(String, String)> _categories(AppLocalizations l) => [
    for (final name in problemCategories)
      (
        name,
        switch (name) {
          'crash' => l.reportCategoryCrash,
          'display' => l.reportCategoryDisplay,
          'sound' => l.reportCategorySound,
          'translation' => l.reportCategoryTranslation,
          _ => l.reportCategoryOther,
        },
      ),
  ];
}
