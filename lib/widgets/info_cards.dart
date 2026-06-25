import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  const InfoCard(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(text)));
}

class ErrorCard extends StatelessWidget {
  const ErrorCard(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
      );
}
