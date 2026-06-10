import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';

class JumpDetailsScreen extends StatefulWidget {
  final String jumpType;

  const JumpDetailsScreen({super.key, required this.jumpType});

  @override
  State<JumpDetailsScreen> createState() => _JumpDetailsScreenState();
}

class _JumpDetailsScreenState extends State<JumpDetailsScreen> {
  final _heightCtrl = TextEditingController();

  void _addJump() {
    if (_heightCtrl.text.isEmpty) return;
    final h = double.tryParse(_heightCtrl.text.replaceAll(',', '.'));
    if (h != null) {
      final jump = JumpLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: widget.jumpType,
        date: DateTime.now().toIso8601String().split('T')[0],
        value: h,
      );
      Provider.of<AppState>(context, listen: false).addJumpLog(jump);
      _heightCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final logs = appState.jumpLogs
        .where((l) => l.type == widget.jumpType)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final currentMax = logs.isEmpty
        ? 0.0
        : logs.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jumpType.replaceAll('_', ' ').toUpperCase()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CustomCard(
            color: AppTheme.secondary.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Massimo Salto',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('$currentMax cm',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: AppTheme.secondary)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CustomCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Nuovo Salto (cm)...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                PrimaryButton(text: 'Aggiungi', onPressed: _addJump),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Cronologia Salti',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            const Center(child: Text('Nessun salto registrato.'))
          else
            ...logs.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CustomCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(log.date,
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text('${log.value} cm',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textHighEmphasis)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.error),
                          onPressed: () => appState.deleteJumpLog(log.id),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
