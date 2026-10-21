/// Flujo de aprobación de un plan.
///
/// Los criterios bloqueantes se muestran como impedimento, nombrando el
/// problema concreto. Los justificables piden el texto y no dejan aprobar
/// mientras esté vacío (FR-022, FR-023).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/auditoria/criterio.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

class DialogoAprobacion extends StatefulWidget {
  const DialogoAprobacion({
    super.key,
    required this.plan,
    required this.auditoria,
  });

  final Plan plan;
  final Auditoria auditoria;

  @override
  State<DialogoAprobacion> createState() => _DialogoAprobacionState();
}

class _DialogoAprobacionState extends State<DialogoAprobacion> {
  final Map<String, TextEditingController> _justificaciones = {};

  @override
  void dispose() {
    for (final controlador in _justificaciones.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  TextEditingController _controladorDe(String criterioId) =>
      _justificaciones.putIfAbsent(criterioId, TextEditingController.new);

  bool get _todasLasJustificacionesEscritas {
    final resultado = widget.auditoria.evaluar(widget.plan);
    for (final criterio in resultado.justificablesEnRojo) {
      if (_controladorDe(criterio.id).text.trim().isEmpty) return false;
    }
    return true;
  }

  List<Justificacion> get _justificacionesEscritas {
    final ahora = DateTime.now();
    final resultado = widget.auditoria.evaluar(widget.plan);
    return [
      for (final criterio in resultado.justificablesEnRojo)
        Justificacion(
          criterioId: criterio.id,
          texto: _controladorDe(criterio.id).text.trim(),
          fecha: ahora,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final resultado = widget.auditoria.evaluar(widget.plan);
    final bloqueantes = resultado.bloqueantesEnRojo;
    final justificables = resultado.justificablesEnRojo;

    final puedeAprobar =
        bloqueantes.isEmpty && _todasLasJustificacionesEscritas;

    return AlertDialog(
      title: const Text('Aprobar plan'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bloqueantes.isNotEmpty) ...[
                // **Cuidado, no error.** La app no ha fallado: ha encontrado
                // un incumplimiento que la metodología no deja justificar. Es
                // un límite, no una avería (FR-016).
                Text(
                  'No se puede aprobar',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: context.colores.cuidado),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Estos incumplimientos no admiten justificación:',
                ),
                const SizedBox(height: 8),
                for (final criterio in bloqueantes)
                  _Impedimento(criterio: criterio),
                const Divider(height: 24),
              ],

              if (justificables.isNotEmpty) ...[
                Text(
                  'Requieren justificación escrita',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final criterio in justificables)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(criterio.nombre),
                        Text(
                          criterio.observacion,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _controladorDe(criterio.id),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Por qué esta desviación es deliberada',
                            isDense: true,
                          ),
                          maxLines: 2,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
              ],

              if (bloqueantes.isEmpty && justificables.isEmpty)
                const Text(
                  'Los once criterios están en verde. El plan se puede '
                  'aprobar tal cual.',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: puedeAprobar
              ? () => Navigator.of(context).pop(_justificacionesEscritas)
              : null,
          child: const Text('Aprobar'),
        ),
      ],
    );
  }
}

class _Impedimento extends StatelessWidget {
  const _Impedimento({required this.criterio});

  final CriterioEvaluado criterio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, size: 16, color: context.colores.cuidado),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterio.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  criterio.observacion,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
