/// Paso 2: cuándo nació.
///
/// **Se dice para qué, en la misma pantalla.** Pedirle la fecha de nacimiento a
/// alguien sin decirle por qué es pedirle un dato personal a cambio de nada, y
/// el principio V exige que todo dato tenga su uso declarado donde se pide.
///
/// El uso es uno solo: saber si es menor de 18. No toca la categoría ni la
/// generación de planes, y una prueba de frontera lo vigila (garantía A7).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

class PasoNacimiento extends StatelessWidget {
  const PasoNacimiento({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAlta>();
    final fecha = estado.perfil.fechaNacimiento;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Cuándo naciste?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Espaciado.corto),
        const Text(
          'Lo usamos para una sola cosa: saber si eres menor de 18 años. '
          'No cambia tu categoría ni tu entrenamiento, que dependen de tus '
          'habilidades.',
        ),
        const SizedBox(height: Espaciado.seccion),

        BotonPrincipal(
          clave: const Key('alta-elegir-fecha'),
          etiqueta: fecha == null
              ? 'Elegir mi fecha de nacimiento'
              : _enPalabras(fecha),
          icono: Icons.event_outlined,
          alPulsar: () async {
            final ahora = DateTime.now();
            final elegida = await showDatePicker(
              context: context,
              initialDate: fecha ?? DateTime(ahora.year - 15),
              firstDate: DateTime(1900),
              lastDate: ahora,
              helpText: 'Tu fecha de nacimiento',
              cancelText: 'Cancelar',
              confirmText: 'Listo',
            );

            if (elegida != null) estado.escribirNacimiento(elegida);
          },
        ),

        if (estado.esMenor) ...[
          const SizedBox(height: Espaciado.amplio),
          // **Informativo, no de cuidado.** Ser menor no es un problema ni un
          // obstáculo: se entra igual y se usa la app igual. Lo único que
          // cambia es que hace falta el permiso de alguien para que los datos
          // salgan del teléfono.
          const Aviso(
            tono: TonoDeAviso.informativo,
            claveDelMensaje: Key('alta-aviso-menor'),
            mensaje: 'Como eres menor de edad, después te pediremos el correo '
                'de tu padre, madre o acudiente para pedirle permiso. Puedes '
                'usar la app igual mientras tanto.',
          ),
        ],
      ],
    );
  }

  /// La fecha como la diría alguien, no como la escribe una máquina.
  static String _enPalabras(DateTime fecha) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];

    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }
}
