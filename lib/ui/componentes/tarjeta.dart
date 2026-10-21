/// La tarjeta, decidida una vez.
///
/// `Card` de Material ya trae el borde, el radio y el color del tema. Lo que
/// cada pantalla repetía era el `Padding` de dentro —a veces 12, a veces 16, a
/// veces 24— y eso es lo que aquí deja de ser una decisión de cada sitio.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.alPulsar,
    this.holgada = false,
  });

  final Widget child;

  /// Si la tarjeta entera se puede tocar.
  final VoidCallback? alPulsar;

  /// Más aire dentro, para las tarjetas que son toda la pantalla.
  ///
  /// Dos opciones y no un número: con un número libre volvemos a tener doce
  /// rellenos distintos.
  final bool holgada;

  @override
  Widget build(BuildContext context) {
    final relleno = EdgeInsets.all(
      holgada ? Espaciado.seccion : Espaciado.normal,
    );

    if (alPulsar == null) {
      return Card(child: Padding(padding: relleno, child: child));
    }

    return Card(
      // `InkWell` dentro de la tarjeta y no al revés: así el destello del toque
      // se recorta con el radio de la tarjeta en lugar de salirse por las
      // esquinas.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Padding(padding: relleno, child: child),
      ),
    );
  }
}
