import 'package:flutter/material.dart';

/// Each dialog owns its form until the route is disposed, including pop animation.
Future<String?> askChatText316(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  String? explanation,
  String? original,
  String confirmLabel = 'Salva',
}) => showDialog<String>(
  context: context,
  builder: (_) => _ChatTextDialog316(
    title: title,
    hint: hint,
    initial: initial,
    explanation: explanation,
    original: original,
    confirmLabel: confirmLabel,
  ),
);

Future<String?> requestCorrection316(
  BuildContext context, {
  required String original,
  required bool hasPrompt,
}) => askChatText316(
  context,
  title: hasPrompt ? 'Correggi la risposta' : 'Correggi il messaggio spontaneo',
  hint: hasPrompt
      ? 'Scrivi la risposta corretta…'
      : 'Scrivi una frase completa che chiarisca il collegamento…',
  original: original,
  explanation: hasPrompt
      ? null
      : 'Non è una risposta a una tua domanda. La correzione sarà registrata '
        'come esperienza esplicita, non usata come nome di una categoria.',
  confirmLabel: 'Impara',
);

Future<String?> requestVariationPrompt316(BuildContext context) => askChatText316(
  context,
  title: 'Contesto della variazione',
  hint: 'A quale domanda o situazione deve rispondere?',
  explanation: 'Questo messaggio è spontaneo e non ha una tua domanda '
      'associata. Indica il contesto; poi potrai aggiungere testo, foto o audio.',
  confirmLabel: 'Continua',
);

class _ChatTextDialog316 extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;
  final String? explanation;
  final String? original;
  final String confirmLabel;

  const _ChatTextDialog316({
    required this.title,
    required this.hint,
    required this.initial,
    required this.explanation,
    required this.original,
    required this.confirmLabel,
  });

  @override
  State<_ChatTextDialog316> createState() => _ChatTextDialog316State();
}

class _ChatTextDialog316State extends State<_ChatTextDialog316> {
  final _form = GlobalKey<FormState>();
  String _value = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.original != null) ...[
              Text(widget.original!, maxLines: 5, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
            ],
            if (widget.explanation != null) ...[
              Text(widget.explanation!),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const ValueKey('chat-feedback-text-316'),
              initialValue: widget.initial,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              maxLength: 1600,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Scrivi un testo prima di continuare.' : null,
              onSaved: (value) => _value = (value ?? '').trim(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_form.currentState?.validate() ?? false)) return;
          _form.currentState!.save();
          Navigator.of(context).pop(_value);
        },
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}

class CuriositySkipButton316 extends StatelessWidget {
  final bool busy;
  final VoidCallback onSkip;
  const CuriositySkipButton316({super.key, required this.busy, required this.onSkip});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: busy ? null : onSkip,
    icon: const Icon(Icons.skip_next_outlined, size: 18),
    label: const Text('Salta'),
  );
}
