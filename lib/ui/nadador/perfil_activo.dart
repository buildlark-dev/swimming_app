/// Quién está usando la app como nadador.
///
/// Decisión D4 de `specs/003-consumo-del-nadador/research.md`: **no hay
/// autenticación de nadador en esta feature**. El perfil activo se elige
/// localmente entre los que el entrenador ya creó.
///
/// El principio V es explícito en que mientras no exista el registro de
/// consentimiento verificable, la app se usa **solo con perfiles de prueba o
/// con el propio entrenador**. Las cuentas y los roles son la feature 004, y
/// hasta entonces esta pantalla lo dice en voz alta en lugar de disimularlo.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/calculo/el_plan_de_ahora.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';

class SelectorDePerfil extends StatelessWidget {
  const SelectorDePerfil({
    super.key,
    required this.estado,
    required this.nadadores,
    required this.planes,
    this.asignaciones = const <Asignacion>[],
    required this.alElegir,
  });

  final EstadoNadador estado;
  final List<Nadador> nadadores;

  /// Planes **publicados**. Un borrador o un aprobado no son del nadador.
  final List<Plan> planes;

  /// A quién se le entregó cada plan.
  final List<Asignacion> asignaciones;

  final Future<void> Function(Nadador) alElegir;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined),
                const SizedBox(width: 8),
                // **`Expanded`, no un `Text` suelto.** Sin esto la fila se
                // salía 82 píxeles a 360 puntos, y no lo veía nadie: la
                // entrada «sesión del día» del banco del tema se monta sin
                // selector, así que este camino no se medía. Un banco solo
                // mide los caminos que monta.
                Expanded(
                  child: Text(
                    'Estás viendo la app como',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (nadadores.isEmpty)
              const Text(
                'Todavía no hay perfiles. Crea uno en la pestaña Nadadores.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final nadador in nadadores)
                    ChoiceChip(
                      label: Text(nadador.nombre),
                      selected: estado.nadador?.id == nadador.id,
                      onSelected: (_) => alElegir(nadador),
                    ),
                ],
              ),

            if (estado.nadador != null && estado.plan == null) ...[
              const SizedBox(height: 12),
              Text(
                planes.isEmpty
                    ? 'No hay ningún plan publicado todavía. Genera un '
                          'microciclo, apruébalo y entrégalo desde el editor.'
                    : 'Hay planes publicados, pero ninguno asignado a este '
                          'perfil. Entrégale uno desde el editor.',
                style: TextStyle(color: esquema.onSurfaceVariant),
              ),
            ],

            const Divider(height: 24),
            // Esto no es una nota al pie: es la condición bajo la que esta
            // feature se puede usar hasta que exista la 004.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: esquema.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin cuentas todavía: el perfil se elige aquí. Úsalo solo '
                    'con perfiles de prueba o contigo mismo hasta que exista el '
                    'registro de consentimiento.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: esquema.outline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// El plan publicado que le corresponde a un nadador, si lo hay.
///
/// Las dos condiciones son independientes y las dos hacen falta:
///
/// - **publicado** (FR-001): un `borrador` o un `aprobado` no son de nadie
///   todavía. Aprobar no es entregar.
/// - **asignado**: la entrega es una [Asignacion], un documento por nadador, y
///   no una lista dentro del plan. Un plan aprobado es inmutable, así que
///   asignarle alguien después no puede ser escribir sobre él; y las reglas de
///   acceso no saben recorrer listas, con lo que la puerta de publicación no
///   podría hacerse cumplir en el servidor.
///
/// De haber varios, **el de ahora**: el que contiene hoy (`elPlanDeAhora`).
///
/// Esto se quedaba con el último de la lista, y hasta la feature 009 eso
/// quería decir «el plan que le entregaron», porque tenía uno. Desde que
/// existen los macrociclos cada mesociclo es un plan asignado, así que «el
/// último» pasó a ser el que la consulta devolviera de último: en el recorrido
/// de la 010 le tocó el Mesociclo 3, que empieza tres meses más tarde.
///
/// `hoy` entra como dato y no como `DateTime.now()` aquí dentro, por lo mismo
/// que en el resto: cuatro pruebas del HUB se pusieron rojas solas al cambiar
/// el día en la feature 007.
Plan? planDe(
  Nadador nadador,
  List<Plan> planes,
  List<Asignacion> asignaciones, {
  required DateTime hoy,
}) {
  final id = nadador.id;
  if (id == null) return null;

  final suyos = asignaciones
      .where((a) => a.nadadorId == id)
      .map((a) => a.planId)
      .toSet();

  final publicados = planes
      .where((p) => p.estado == EstadoPlan.publicado)
      .where((p) => p.id != null && suyos.contains(p.id))
      .toList();

  return elPlanDeAhora(publicados, hoy);
}
