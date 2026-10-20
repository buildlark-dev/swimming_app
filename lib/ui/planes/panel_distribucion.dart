/// Panel de distribución del plan.
///
/// Por cada zona, el valor real, el prescrito y la diferencia. Más el
/// porcentaje técnico y el reparto de estilos.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/auditoria/tolerancia.dart';
import 'package:natacion_app/dominio/calculo/agregacion_plan.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/modelo_tid.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

class PanelDistribucion extends StatelessWidget {
  const PanelDistribucion({
    super.key,
    required this.plan,
    this.tolerancia = Tolerancia.predeterminada,
  });

  final Plan plan;
  final Tolerancia tolerancia;

  @override
  Widget build(BuildContext context) {
    final agregacion = AgregacionPlan(plan);
    final porZona = agregacion.repartoPorZona;
    final porEstilo = agregacion.repartoDeEstilos;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Distribución del plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${plan.metros} m · '
                  '${plan.porcentajeTecnico.toStringAsFixed(1)}% técnico',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            if (agregacion.metrosSinZona > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${agregacion.metrosSinZona} m sin zona asignada: la '
                  'distribución no es fiable mientras queden series sin zona.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            if (plan.faseAtr != null) ...[
              const SizedBox(height: 12),
              _ModeloDeLaFase(plan: plan, agregacion: agregacion),
            ],

            if (porZona.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Zonas de intensidad frente a ${plan.faseAtr?.nombre ?? 'la fase'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final reparto in porZona)
                _FilaReparto(reparto: reparto, tolerancia: tolerancia),
            ],

            if (porEstilo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Estilos, con objetivo ${plan.estiloObjetivo.nombre}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final reparto in porEstilo)
                _FilaReparto(reparto: reparto, tolerancia: tolerancia),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaReparto extends StatelessWidget {
  const _FilaReparto({required this.reparto, required this.tolerancia});

  final Reparto reparto;
  final Tolerancia tolerancia;

  @override
  Widget build(BuildContext context) {
    final dentro = tolerancia.admite(reparto.diferencia);
    final color = dentro ? null : Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(reparto.etiqueta, style: TextStyle(color: color)),
          ),
          SizedBox(
            width: 70,
            child: Text('${reparto.metros} m', textAlign: TextAlign.end),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: (reparto.porcentajeReal / 100).clamp(0.0, 1.0),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(
              '${reparto.porcentajeReal.toStringAsFixed(1)}% de '
              '${reparto.porcentajePrescrito.toStringAsFixed(0)}% '
              '(${reparto.diferencia >= 0 ? '+' : ''}'
              '${reparto.diferencia.toStringAsFixed(1)})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que de verdad se audita: las tres zonas contra el envolvente publicado.
///
/// Va arriba del desglose por zona a propósito. El desglose fino es criterio
/// del entrenador y no suspende; esto sí, y por eso lleva la fuente a la vista:
/// tiene derecho a saber qué respalda lo que la app le exige.
class _ModeloDeLaFase extends StatelessWidget {
  const _ModeloDeLaFase({required this.plan, required this.agregacion});

  final Plan plan;
  final AgregacionPlan agregacion;

  @override
  Widget build(BuildContext context) {
    final fase = plan.faseAtr!;
    final modelo = fase.modelo;
    final reales = agregacion.porcentajePorTid;
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Modelo de ${fase.nombre}: ${modelo.nombre}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Text(
              modelo.patron,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final tid in ZonaTid.values)
          _FilaTid(
            tid: tid,
            real: reales[tid] ?? 0,
            rango: modelo.rangoDe(tid),
          ),
        const SizedBox(height: 6),
        Text(
          'Envolvente de ${modelo.fuente}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _FilaTid extends StatelessWidget {
  const _FilaTid({
    required this.tid,
    required this.real,
    required this.rango,
  });

  final ZonaTid tid;
  final double real;
  final RangoTid rango;

  @override
  Widget build(BuildContext context) {
    final dentro = rango.contiene(real);
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              tid.abreviatura,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('${real.toStringAsFixed(1)}%'),
          ),
          SizedBox(
            width: 90,
            child: Text(
              rango.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Icon(
            dentro ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: dentro ? esquema.primary : esquema.error,
          ),
          if (!dentro) ...[
            const SizedBox(width: 6),
            Text(
              '${rango.desviacion(real) >= 0 ? '+' : ''}'
              '${rango.desviacion(real).toStringAsFixed(1)} puntos',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: esquema.error,
                        ),
            ),
          ],
          const Spacer(),
          Expanded(
            flex: 3,
            child: Text(
              tid.descripcion,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
