/// El alta, paso a paso.
///
/// **Un paso por pantalla, no un formulario de ocho campos** (FR-002). No es
/// una preferencia de estilo: quien se da de alta aquí puede tener nueve años y
/// estar de pie al borde de una piscina, y un formulario largo en un teléfono
/// es donde la gente abandona.
///
/// Volver atrás no borra nada, y cerrar la app a mitad tampoco (garantía A2).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/alta/paso_acudiente.dart';
import 'package:natacion_app/ui/alta/paso_nacimiento.dart';
import 'package:natacion_app/ui/alta/paso_nombre.dart';
import 'package:natacion_app/ui/alta/paso_pais.dart';
import 'package:natacion_app/ui/alta/paso_terminos.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

class PantallaAlta extends StatelessWidget {
  const PantallaAlta({super.key, required this.alTerminar});

  /// Qué hacer cuando el alta acaba. Lo decide quien monta la pantalla.
  final void Function(ResultadoDelAlta) alTerminar;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAlta>();

    return Scaffold(
      appBar: AppBar(
        title: Text(estado.pasoActual.titulo),
        leading: estado.esElPrimero
            ? null
            : IconButton(
                key: const Key('alta-volver'),
                icon: const Icon(Icons.arrow_back),
                onPressed: estado.retroceder,
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: estado.numeroDePaso / estado.totalDePasos,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Espaciado.amplio),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paso ${estado.numeroDePaso} de ${estado.totalDePasos}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: Espaciado.normal),

              Expanded(
                child: SingleChildScrollView(
                  child: switch (estado.pasoActual) {
                    PasoDelAlta.nombre => const PasoNombre(),
                    PasoDelAlta.nacimiento => const PasoNacimiento(),
                    PasoDelAlta.pais => const PasoPais(),
                    PasoDelAlta.terminos => const PasoTerminos(),
                    PasoDelAlta.acudiente => const PasoAcudiente(),
                  },
                ),
              ),

              if (estado.fallo != null) ...[
                const SizedBox(height: Espaciado.normal),
                Aviso(
                  tono: TonoDeAviso.cuidado,
                  mensaje: estado.fallo!,
                  claveDelMensaje: const Key('alta-fallo'),
                ),
              ],

              const SizedBox(height: Espaciado.amplio),
              _Siguiente(estado: estado, alTerminar: alTerminar),
            ],
          ),
        ),
      ),
    );
  }
}

class _Siguiente extends StatelessWidget {
  const _Siguiente({required this.estado, required this.alTerminar});

  final EstadoAlta estado;
  final void Function(ResultadoDelAlta) alTerminar;

  @override
  Widget build(BuildContext context) {
    if (!estado.esElUltimo) {
      return BotonPrincipal(
        clave: const Key('alta-siguiente'),
        etiqueta: 'Continuar',
        alPulsar: estado.elPasoEstaListo ? estado.avanzar : null,
      );
    }

    return BotonPrincipal(
      clave: const Key('alta-terminar'),
      etiqueta: 'Terminar',
      trabajando: estado.enviando,
      alPulsar: estado.elPasoEstaListo
          ? () async {
              final resultado = await estado.terminar();
              if (resultado != null) alTerminar(resultado);
            }
          : null,
    );
  }
}
