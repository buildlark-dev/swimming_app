/// Cómo se ve cada estado de un plan.
///
/// **`aprobado` no puede verse como `publicado`.** Aprobar no es entregar: un
/// plan aprobado lleva la firma del entrenador y todavía no lo tiene nadie, y
/// uno publicado ya es el entrenamiento de alguien. Confundirlos borraría la
/// distinción que el principio IV protege, y en la práctica significaría que el
/// entrenador cree haber entregado un plan que ningún nadador ha recibido.
///
/// Por eso llevan **dos señales**, no una: color distinto **y** icono distinto.
/// El color no es nunca la única señal (FR-015).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/ui/tema/avisos.dart';

abstract final class EstadosDePlan {
  /// El color del estado, en el modo que toque.
  static Color colorDe(BuildContext context, EstadoPlan estado) {
    final colores = context.colores;

    return switch (estado) {
      EstadoPlan.borrador => colores.borrador,
      EstadoPlan.aprobado => colores.aprobado,
      EstadoPlan.publicado => colores.publicado,
    };
  }

  /// El icono del estado.
  ///
  /// Los tres cuentan la misma historia en orden: algo a medio escribir, algo
  /// firmado, algo entregado. El de `aprobado` es un sello y el de `publicado`
  /// una entrega, no dos vistos distintos.
  static IconData iconoDe(EstadoPlan estado) => switch (estado) {
        EstadoPlan.borrador => Icons.edit_note,
        EstadoPlan.aprobado => Icons.verified_outlined,
        EstadoPlan.publicado => Icons.send_outlined,
      };

  /// Lo que significa, en una línea.
  ///
  /// Va debajo del nombre del estado porque «aprobado» no le dice a nadie que
  /// el plan sigue sin entregar.
  static String explicacionDe(EstadoPlan estado) => switch (estado) {
        EstadoPlan.borrador => 'Todavía no es de nadie',
        EstadoPlan.aprobado => 'Firmado, pero aún sin entregar',
        EstadoPlan.publicado => 'Es el entrenamiento de alguien',
      };
}
