/// La marca de una zona de intensidad.
///
/// **El color acompaña al nombre, nunca lo sustituye** (FR-016). La abreviatura
/// —`A1`, `AT`, `Máx`— es la notación del entrenador, y la notación es suya: la
/// app la muestra, no la traduce ni la reemplaza por un cuadrito de color.
///
/// Quien no distinga colores lee la abreviatura y no pierde nada. Quien sí los
/// distinga ve de un vistazo que una sesión es toda clara o toda oscura, que es
/// para lo que sirve la rampa.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/ui/tema/dominio/escala_de_zonas.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class EtiquetaDeZona extends StatelessWidget {
  const EtiquetaDeZona({super.key, required this.zona, this.alPulsar});

  final Zona zona;

  /// Para donde la zona se puede cambiar, como el editor.
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final fondo = EscalaDeZonas.fondoDe(context, zona);
    final texto = EscalaDeZonas.textoSobre(context, zona);

    final marca = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaciado.corto,
        vertical: Espaciado.minimo,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Espaciado.radioCorto),
      ),
      child: Text(
        zona.abreviatura,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: texto),
      ),
    );

    if (alPulsar == null) return marca;

    return Semantics(
      button: true,
      label: '${zona.abreviatura}, ${zona.nombre}',
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(Espaciado.radioCorto),
        child: ConstrainedBox(
          // El área que responde llega al mínimo aunque la marca sea pequeña
          // (FR-006). La abreviatura `A1` ocupa muy poco y aun así hay que
          // poder acertarla con el dedo mojado.
          constraints: const BoxConstraints(
            minWidth: Espaciado.areaPulsableMinima,
            minHeight: Espaciado.areaPulsableMinima,
          ),
          child: Center(child: marca),
        ),
      ),
    );
  }
}
