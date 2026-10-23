/// Paso 5, solo para menores: el correo del acudiente.
///
/// **Se dice para qué, en esta misma pantalla** (FR-014). Pedirle a una niña de
/// doce años el correo de su madre sin explicarle por qué sería pedirle un dato
/// de otra persona a ciegas.
///
/// **Y se puede seguir sin darlo** (FR-019). Lo que no se puede es dejarla sin
/// saber qué pasa si no lo da: entra igual, usa la app igual, y lo que anote se
/// queda en su teléfono hasta que alguien autorice.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

class PasoAcudiente extends StatelessWidget {
  const PasoAcudiente({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAlta>();
    final problema = estado.problemaDelAcudiente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'El correo de tu acudiente',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Espaciado.corto),
        const Text(
          'Como eres menor de edad, hace falta el permiso de tu padre, madre '
          'o acudiente para guardar tus datos. Le enviaremos un correo con un '
          'enlace para que decida. No tiene que crearse ninguna cuenta.',
        ),
        const SizedBox(height: Espaciado.seccion),

        Campo(
          key: const Key('alta-campo-acudiente'),
          etiqueta: 'Correo de tu acudiente',
          valorInicial: estado.perfil.correoDelAcudiente,
          pista: 'correo@ejemplo.com',
          tipoDeTeclado: TextInputType.emailAddress,
          problema: problema?.mensaje,
          alCambiar: estado.escribirCorreoDelAcudiente,
        ),

        const SizedBox(height: Espaciado.amplio),

        // **Informativo, no de cuidado.** No dar el correo no es un error ni
        // una falta: es una decisión legítima, y lo que toca es decir qué
        // ocurre entonces, sin dramatizarlo.
        const Aviso(
          tono: TonoDeAviso.informativo,
          claveDelMensaje: Key('alta-aviso-sin-acudiente'),
          mensaje: 'Si prefieres no ponerlo ahora, puedes continuar igual. '
              'Podrás entrar, ver tu plan y anotar cómo te fue; lo que '
              'escribas se guarda en tu teléfono y se enviará a tu entrenador '
              'cuando tu acudiente dé el permiso.',
        ),
      ],
    );
  }
}
