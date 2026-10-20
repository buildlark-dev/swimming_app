/// El título de una sección, con su cifra al lado.
///
/// Este componente sale de la fase 3. La garantía V7 destapó **cuatro sitios**
/// que escribían lo mismo —un `Row` con el título a la izquierda y una cifra a
/// la derecha— y los cuatro se desbordaban con la letra del sistema grande,
/// porque un `Row` no sabe bajar lo que no cabe.
///
/// Los cuatro se arreglaron igual: `Wrap` en lugar de `Row`, y un ancho
/// explícito para que la cifra siga a la derecha cuando sí cabe. Escribir ese
/// arreglo cuatro veces es garantizar que el quinto sitio lo escriba mal.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class CabeceraSeccion extends StatelessWidget {
  const CabeceraSeccion({
    super.key,
    required this.titulo,
    this.cifra,
    this.estilo,
    this.estiloDeCifra,
    this.icono,
  });

  final String titulo;

  /// Lo que va a la derecha: metros, un porcentaje, una fecha.
  ///
  /// Nulo cuando la sección solo tiene nombre.
  final String? cifra;

  /// Para las cabeceras que no son del tamaño normal de sección.
  final TextStyle? estilo;
  final TextStyle? estiloDeCifra;

  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    final nombre = icono == null
        ? Text(titulo, style: estilo ?? texto.titleMedium)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: Espaciado.iconoEnLinea),
              const SizedBox(width: Espaciado.corto),
              Text(titulo, style: estilo ?? texto.titleMedium),
            ],
          );

    // El `SizedBox` es lo que mantiene la cifra a la derecha: muchas de las
    // columnas donde vive esta cabecera no estiran a sus hijos, y sin un ancho
    // explícito el `Wrap` se encoge y `spaceBetween` no tiene nada que
    // repartir.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Espaciado.corto,
        runSpacing: Espaciado.minimo,
        children: [
          nombre,
          if (cifra != null)
            Text(cifra!, style: estiloDeCifra ?? texto.bodySmall),
        ],
      ),
    );
  }
}
