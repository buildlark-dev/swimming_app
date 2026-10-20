/// En qué estado está un plan.
///
/// Borrador, aprobado, publicado. Lleva **tres señales**, no una: el nombre, un
/// icono propio y un color propio.
///
/// Tres y no dos porque la confusión que importa aquí no es de accesibilidad,
/// es de significado: «aprobado» no le dice a nadie que el plan sigue sin
/// entregar. Por eso, cuando hay sitio, debajo va qué significa.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/ui/tema/dominio/estados_de_plan.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class EtiquetaDeEstado extends StatelessWidget {
  const EtiquetaDeEstado({
    super.key,
    required this.estado,
    this.conExplicacion = false,
  });

  final EstadoPlan estado;

  /// Añade qué significa el estado debajo del nombre.
  final bool conExplicacion;

  @override
  Widget build(BuildContext context) {
    final color = EstadosDePlan.colorDe(context, estado);

    final marca = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaciado.corto,
        vertical: Espaciado.minimo,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Espaciado.radioCorto),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            EstadosDePlan.iconoDe(estado),
            size: Espaciado.iconoEnLinea,
            color: color,
          ),
          const SizedBox(width: Espaciado.minimo),
          Text(
            estado.nombre,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );

    if (!conExplicacion) return marca;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        marca,
        const SizedBox(height: Espaciado.minimo),
        Text(
          EstadosDePlan.explicacionDe(estado),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
