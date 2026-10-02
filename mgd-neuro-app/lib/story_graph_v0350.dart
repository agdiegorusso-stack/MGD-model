import 'dart:math';
import 'package:flutter/material.dart';
import 'narrative_memory_v0350.dart';

/// Every vertex/edge is backed by an event/role, never decorative brain nodes.
/// Only the current graph page is laid out; every event remains in the timeline.
class StoryGraph350 extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final void Function(Map<String, dynamic>) onEvent;
  final void Function(String) onEntity;
  const StoryGraph350(
      {super.key,
      required this.events,
      required this.onEvent,
      required this.onEntity});
  @override
  State<StoryGraph350> createState() => _StoryGraph350State();
}

class _StoryGraph350State extends State<StoryGraph350> {
  final transform = TransformationController();
  int page = 0;
  double width = 0;
  late List<_Node350> nodes;
  late List<_Edge350> edges;
  @override
  void initState() {
    super.initState();
    _layout();
  }

  @override
  void didUpdateWidget(covariant StoryGraph350 old) {
    super.didUpdateWidget(old);
    if (!identical(old.events, widget.events)) {
      page = 0;
      _layout();
    }
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void _layout() {
    final map = <String, _Node350>{};
    edges = [];
    final pageEvents = widget.events.skip(page * 12).take(12);
    for (final data in pageEvents) {
      final e = Event350.fromJson(data);
      if (e.kind == 'cause') continue;
      final event = 'event:${e.id}';
      map[event] = _Node350(
          event, '${e.negative ? 'non ' : ''}${e.surface}', true, data);
      for (final role in <String, String>{
        'agente': e.subject,
        'oggetto': e.object,
        'destinatario': e.target,
        'luogo': e.location
      }.entries) {
        if (role.value.isEmpty) continue;
        final id = 'entity:${role.value}';
        map.putIfAbsent(id, () => _Node350(id, role.value, false, null));
        edges.add(role.key == 'agente'
            ? _Edge350(id, event, role.key)
            : _Edge350(event, id, role.key));
      }
    }
    nodes = map.values.toList();
    for (var i = 0; i < nodes.length; i++) {
      final a = 2 * pi * i / max(1, nodes.length), r = 140 + (i % 3) * 24;
      nodes[i].position = Offset(325 + r * cos(a), 220 + r * sin(a));
    }
    // Bounded deterministic force layout. This layout has no cognitive interpretation.
    for (var step = 0; step < 90; step++) {
      final force = {for (final n in nodes) n.id: Offset.zero};
      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          var delta = nodes[i].position - nodes[j].position;
          final distance = max(8.0, delta.distance);
          if (delta.distance < .01) delta = const Offset(1, 0);
          final f = delta / distance * (1500 / (distance * distance));
          force[nodes[i].id] = force[nodes[i].id]! + f;
          force[nodes[j].id] = force[nodes[j].id]! - f;
        }
      }
      for (final e in edges) {
        final a = map[e.a]!, b = map[e.b]!, delta = b.position - a.position;
        final distance = max(1.0, delta.distance),
            f = delta / distance * ((distance - 100) * .009);
        force[e.a] = force[e.a]! + f;
        force[e.b] = force[e.b]! - f;
      }
      for (final n in nodes) {
        final f = force[n.id]! + (const Offset(325, 220) - n.position) * .001;
        final p = n.position + f * min(4.0, 80 / (step + 15));
        n.position = Offset(p.dx.clamp(68, 582), p.dy.clamp(40, 400));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          const Expanded(
              child: Text('Mappa delle esperienze di lettura',
                  style: TextStyle(fontWeight: FontWeight.w600))),
          IconButton(
              tooltip: 'Eventi precedenti',
              onPressed: page == 0
                  ? null
                  : () {
                      setState(() {
                        page--;
                        _layout();
                      });
                    },
              icon: const Icon(Icons.chevron_left)),
          Text('${page + 1}/${max(1, (widget.events.length / 12).ceil())}'),
          IconButton(
              tooltip: 'Eventi successivi',
              onPressed: (page + 1) * 12 >= widget.events.length
                  ? null
                  : () {
                      setState(() {
                        page++;
                        _layout();
                      });
                    },
              icon: const Icon(Icons.chevron_right)),
        ]),
        const Text(
            'Riquadri: eventi. Cerchi: entità. Le frecce indicano i ruoli; tocca per aprire. Pizzica per ingrandire.'),
        const SizedBox(height: 8),
        SizedBox(
            height: 310,
            child: LayoutBuilder(builder: (context, box) {
              if (width != box.maxWidth) {
                width = box.maxWidth;
                transform.value = Matrix4.diagonal3Values(
                    min(1, width / 650), min(1, width / 650), 1);
              }
              final scheme = Theme.of(context).colorScheme;
              return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: InteractiveViewer(
                          transformationController: transform,
                          constrained: false,
                          minScale: .35,
                          maxScale: 3.5,
                          boundaryMargin: const EdgeInsets.all(200),
                          child: SizedBox(
                              width: 650,
                              height: 440,
                              child: Stack(children: [
                                Positioned.fill(
                                    child: CustomPaint(
                                        painter: _Edges350(
                                            nodes, edges, scheme.outline))),
                                for (final n in nodes)
                                  Positioned(
                                      left: n.position.dx - 54,
                                      top: n.position.dy - 25,
                                      width: 108,
                                      height: 50,
                                      child: Semantics(
                                          button: true,
                                          label:
                                              '${n.event ? 'Evento' : 'Entità'}: ${n.label}',
                                          child: Tooltip(
                                              message: n.label,
                                              child: Material(
                                                  color: n.event
                                                      ? scheme.primaryContainer
                                                      : scheme
                                                          .secondaryContainer,
                                                  shape: n.event
                                                      ? RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8))
                                                      : const StadiumBorder(),
                                                  child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                      onTap: () {
                                                        if (n.data != null) {
                                                          widget
                                                              .onEvent(n.data!);
                                                        } else {
                                                          widget.onEntity(
                                                              n.label);
                                                        }
                                                      },
                                                      child: Center(
                                                          child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          5),
                                                              child: Text(n.label,
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow
                                                                      .ellipsis,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: TextStyle(fontSize: 15, color: n.event ? scheme.onPrimaryContainer : scheme.onSecondaryContainer)))))))))
                              ])))));
            })),
      ]);
}

class _Node350 {
  final String id, label;
  final bool event;
  final Map<String, dynamic>? data;
  Offset position = Offset.zero;
  _Node350(this.id, this.label, this.event, this.data);
}

class _Edge350 {
  final String a, b, role;
  _Edge350(this.a, this.b, this.role);
}

class _Edges350 extends CustomPainter {
  final List<_Node350> nodes;
  final List<_Edge350> edges;
  final Color color;
  _Edges350(this.nodes, this.edges, this.color);
  @override
  void paint(Canvas c, Size size) {
    final map = {for (final n in nodes) n.id: n.position},
        p = Paint()
          ..color = color
          ..strokeWidth = 1.5;
    for (final e in edges) {
      final a = map[e.a]!,
          b = map[e.b]!,
          d = b - a,
          len = max(1.0, d.distance),
          u = d / len;
      final start = a + u * 30, end = b - u * 32;
      c.drawLine(start, end, p);
      final normal = Offset(-u.dy, u.dx),
          path = Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(
                (end - u * 9 + normal * 5).dx, (end - u * 9 + normal * 5).dy)
            ..lineTo(
                (end - u * 9 - normal * 5).dx, (end - u * 9 - normal * 5).dy)
            ..close();
      c.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _Edges350 old) =>
      !identical(nodes, old.nodes) || color != old.color;
}
