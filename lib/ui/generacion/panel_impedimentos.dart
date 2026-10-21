/// Panel que explica por qué no se pudo generar.
///
/// Cada impedimento con su explicación en términos que el entrenador
/// reconozca, y los números concretos de la contradicción. Se muestran
/// **todos a la vez**, no de uno en uno.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';

class PanelImpedimentos extends StatelessWidget {
  const PanelImpedimentos({super.key, required this.impedimentos});

  final List<Impedimento> impedimentos;

  @override
  Widget build(BuildContext context) {
    if (impedimentos.isEmpty) return const SizedBox.shrink();

    // **Cuidado, no error.** La app no ha fallado: se ha negado a inventar.
    // Faltan datos, y la metodología prohíbe planificar rellenando huecos a
    // suposición. Es lo contrario de una avería — es la app funcionando como
    // debe— y pintarlo de rojo le decía al entrenador que algo se había roto.
    return Aviso(
      tono: TonoDeAviso.cuidado,
      icono: Icons.block,
      titulo: impedimentos.length == 1
          ? 'No se puede generar'
          : 'No se puede generar: ${impedimentos.length} motivos',
      mensaje: 'La metodología prohíbe planificar con datos faltantes. Un plan '
          'con huecos rellenados a suposición parece válido y no lo es.',
      detalles: [
        const Divider(),
        for (final impedimento in impedimentos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Espaciado.minimo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  impedimento.tipo.descripcion,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(impedimento.explicacion),
              ],
            ),
          ),
      ],
    );
  }
}

/// Avisos y supuestos de un plan que sí se generó.
class PanelAvisosGeneracion extends StatelessWidget {
  const PanelAvisosGeneracion({
    super.key,
    required this.resultado,
  });

  final MicrocicloGenerado resultado;

  @override
  Widget build(BuildContext context) {
    final hayAlgo = resultado.avisos.isNotEmpty ||
        resultado.supuestos.isNotEmpty ||
        resultado.vaciosDeBiblioteca.isNotEmpty;

    if (!hayAlgo) return const SizedBox.shrink();

    // Tono **informativo**: nada ha fallado y nadie se ha equivocado. Son
    // supuestos que el generador tomó y huecos de la biblioteca que no rellenó,
    // y el entrenador tiene derecho a saberlos antes de aprobar.
    return Aviso(
      tono: TonoDeAviso.informativo,
      mensaje: 'Lo que conviene que sepas de este plan',
      detalles: [
        const Divider(),

        for (final aviso in resultado.avisos)
          LineaDeAviso(icono: Icons.healing_outlined, texto: aviso),

        for (final vacio in resultado.vaciosDeBiblioteca)
          LineaDeAviso(
            icono: Icons.search_off,
            texto: '$vacio. No se eligió otro ejercicio en su lugar: '
                'sustituirlo sería inventar por aproximación.',
          ),

        for (final supuesto in resultado.supuestos)
          LineaDeAviso(
            icono: Icons.info_outline,
            texto: '${supuesto.descripcion}. ${supuesto.motivo}',
          ),
      ],
    );
  }
}
