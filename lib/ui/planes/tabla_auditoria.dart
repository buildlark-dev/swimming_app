/// Tabla de auditoría metodológica.
///
/// Muestra los once criterios con su veredicto, su severidad y su observación.
/// Se puede consultar en cualquier momento, no solo al aprobar.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/auditoria/criterio.dart';

class TablaAuditoria extends StatelessWidget {
  const TablaAuditoria({super.key, required this.resultado});

  final ResultadoAuditoria resultado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Auditoría metodológica',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _Resumen(resultado: resultado),
            ],
          ),
          const SizedBox(height: Espaciado.corto),
          for (final criterio in resultado.criterios)
            _FilaCriterio(criterio: criterio, esquema: esquema),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.resultado});

  final ResultadoAuditoria resultado;

  @override
  Widget build(BuildContext context) {
    final enVerde = resultado.criterios.length - resultado.enRojo.length;
    final bloqueantes = resultado.bloqueantesEnRojo.length;

    return Text(
      '$enVerde de ${resultado.criterios.length} en verde'
      '${bloqueantes > 0 ? ' · $bloqueantes bloqueantes' : ''}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _FilaCriterio extends StatelessWidget {
  const _FilaCriterio({required this.criterio, required this.esquema});

  final CriterioEvaluado criterio;
  final ColorScheme esquema;

  @override
  Widget build(BuildContext context) {
    final color = criterio.cumple
        ? null
        : (criterio.severidad == Severidad.bloqueante
            ? esquema.error
            : esquema.tertiary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            criterio.cumple
                ? Icons.check_circle_outline
                : (criterio.severidad == Severidad.bloqueante
                    ? Icons.block
                    : Icons.edit_note),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        criterio.nombre,
                        style: TextStyle(
                          fontWeight: criterio.cumple
                              ? FontWeight.normal
                              : FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    if (!criterio.cumple)
                      Chip(
                        label: Text(
                          criterio.severidad.nombre,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
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
