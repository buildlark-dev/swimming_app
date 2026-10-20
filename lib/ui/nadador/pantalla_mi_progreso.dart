/// Mi progreso: historial de sesiones y adherencia.
///
/// El entrenador eligió el alcance al aclarar la especificación: historial más
/// adherencia **como recuento**, sin gráficas (FR-005a, FR-005b).
///
/// **Funciona sin conexión**, como todo lo que el nadador lee (FR-005).
///
/// Lo que aquí no hay, y es deliberado: ningún número que mezcle lo programado
/// con lo percibido. La adherencia cuenta sesiones; el RPE se muestra al lado,
/// sesión por sesión. El principio VIII prohíbe combinarlos en un mismo
/// indicador.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/nadador/aviso_sincronizacion.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:provider/provider.dart';

class PantallaMiProgreso extends StatelessWidget {
  const PantallaMiProgreso({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoNadador>();
    final progreso = estado.progreso;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi progreso')),
      body: progreso == null
          ? const Padding(
              padding: EdgeInsets.all(Espaciado.amplio),
              child: EstadoVacio(
                icono: Icons.event_busy_outlined,
                titulo: 'Todavía no tienes un plan asignado',
                queHacer: 'Cuando tu entrenador te asigne uno, tu progreso '
                    'aparecerá aquí.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AvisoSincronizacion(estado: estado),
                const SizedBox(height: 8),
                _Adherencia(progreso: progreso),
                const SizedBox(height: 16),
                Text(
                  'Historial',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final entrada in progreso.historial)
                  _Entrada(entrada: entrada),
                const SizedBox(height: 60),
              ],
            ),
    );
  }
}

class _Adherencia extends StatelessWidget {
  const _Adherencia({required this.progreso});

  final ProgresoDelNadador progreso;

  @override
  Widget build(BuildContext context) {
    final delPlan = progreso.adherenciaDelPlan;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesiones completadas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              delPlan.descripcion,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'en todo el plan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (progreso.adherenciaPorSemana.isNotEmpty) ...[
              const Divider(height: 24),
              for (final microciclo in progreso.plan.microciclos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(microciclo.nombre)),
                      Text(
                        progreso.adherenciaPorSemana[microciclo.id]
                                ?.descripcion ??
                            '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({required this.entrada});

  final SesionConRegistro entrada;

  @override
  Widget build(BuildContext context) {
    final registro = entrada.registro;
    final esquema = Theme.of(context).colorScheme;
    final fecha = entrada.sesion.fecha;

    return Card(
      child: ListTile(
        leading: Icon(
          entrada.realizada
              ? Icons.check_circle_outline
              : entrada.tieneRespuesta
                  ? Icons.cancel_outlined
                  : Icons.radio_button_unchecked,
          color: entrada.realizada ? esquema.primary : esquema.outline,
        ),
        title: Text(entrada.sesion.objetivoTecnico),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (fecha != null)
                  '${fecha.day.toString().padLeft(2, '0')}/'
                      '${fecha.month.toString().padLeft(2, '0')}',
                // Carga externa y carga interna, una al lado de la otra pero
                // **nunca combinadas en un mismo número** (principio VIII).
                '${entrada.sesion.metros} m',
                if (registro?.rpePercibido != null)
                  'RPE ${registro!.rpePercibido}',
              ].join(' · '),
            ),
            if (registro != null && registro.observaciones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  registro.observaciones,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (entrada.tieneMolestia)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.healing_outlined,
                        size: 16, color: esquema.error),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        registro!.molestia!.descripcion,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: esquema.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: registro != null,
      ),
    );
  }
}
