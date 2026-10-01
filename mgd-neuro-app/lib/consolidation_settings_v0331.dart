import 'package:flutter/material.dart';
import 'sensory_world_v06.dart';

class ConsolidationSettings331 extends StatelessWidget {
  final MgdWorld06 world;
  final bool busy;
  final ValueChanged<bool> onChanged;
  const ConsolidationSettings331(
      {super.key,
      required this.world,
      required this.busy,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            key: const ValueKey('consolidation-toggle-0331'),
            title: const Text('Consolida connessioni confermate'),
            subtitle: const Text(
                'Rende persistenti i legami con provenienza acquisita. '
                'La persistenza non verifica i fatti. Una correzione può revocarla.'),
            value: world.consolidationEnabled331,
            onChanged: busy ? null : onChanged,
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                  'Connessioni persistenti: ${world.consolidationBasinCount331}'
                  ' / ${world.consolidationEligibleCount331} idonee'
                  ' · ${world.consolidationRevokedCount331} revocate',
                  key: const ValueKey('consolidation-metric-0331'))),
        ]),
      );
}
