/// Los botones, decididos una vez.
///
/// El tamaño mínimo ya lo pone el tema, así que lo que estos componentes añaden
/// es lo otro que se repetía a mano: **el estado de «trabajando»**. Dos
/// pantallas lo escribían igual —un `CircularProgressIndicator` de dieciocho
/// píxeles con grosor dos, dentro del botón, con `onPressed` a nulo— y esa clase
/// de copia es la que acaba divergiendo.
///
/// Importa más de lo que parece: un botón que no avisa de que está trabajando se
/// pulsa dos veces, y pulsar dos veces «Entregar» es entregar dos veces.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

/// La acción principal de una pantalla. Una sola por pantalla.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.etiqueta,
    required this.alPulsar,
    this.clave,
    this.icono,
    this.trabajando = false,
  });

  /// La clave del botón **de dentro**, no la de este envoltorio.
  ///
  /// Hace falta porque las pruebas de las features anteriores buscan el
  /// `FilledButton` por clave y le preguntan si está habilitado. Poner la clave
  /// en el envoltorio las rompió, y eso es exactamente lo que la garantía V13
  /// está ahí para cazar: si un componente nuevo obliga a cambiar una prueba
  /// vieja, es el componente el que está mal.
  final Key? clave;

  final String etiqueta;

  /// Nulo cuando no se puede pulsar todavía. No es lo mismo que `trabajando`:
  /// uno dice «falta algo», el otro dice «espera».
  final VoidCallback? alPulsar;

  final IconData? icono;
  final bool trabajando;

  @override
  Widget build(BuildContext context) {
    final contenido = _Contenido(
      etiqueta: etiqueta,
      icono: icono,
      trabajando: trabajando,
    );

    return FilledButton(
      key: clave,
      onPressed: trabajando ? null : alPulsar,
      child: contenido,
    );
  }
}

// **No hay `BotonSecundario`.**
//
// Lo hubo un rato, y se quitó: la app no tiene hoy ni un solo botón de
// contorno, así que era un componente escrito para un sitio que no existe.
// Cuando el HUB de la feature 007 necesite una acción secundaria de verdad,
// se añade entonces, con su primer uso al lado.
//
// Es la misma disciplina que la de los tokens: si falta uno, se añade cuando
// algo lo pide, no por si acaso.

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.etiqueta,
    required this.icono,
    required this.trabajando,
  });

  final String etiqueta;
  final IconData? icono;
  final bool trabajando;

  @override
  Widget build(BuildContext context) {
    if (trabajando) {
      return const SizedBox(
        height: Espaciado.amplio,
        width: Espaciado.amplio,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (icono == null) return Text(etiqueta);

    // El `Flexible` **no es opcional**.
    //
    // Sin él, «Marcar como realizada» con la letra al 200% se salía 64 píxeles
    // del botón. `FilledButton.icon` de Material lo lleva puesto, y al escribir
    // esta fila a mano se me quedó fuera: lo cazó la garantía V7 en el mismo
    // commit. Es la mejor prueba de que el banco de pantallas de la fase 3
    // sirve para algo.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: Espaciado.iconoEnLinea),
        const SizedBox(width: Espaciado.corto),
        Flexible(child: Text(etiqueta)),
      ],
    );
  }
}
