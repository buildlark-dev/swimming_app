/// Lo que ella puede hacer con su pertenencia, en un solo sitio.
///
/// **Vive en Ajustes porque es donde ella gobierna su cuenta**: al lado de sus
/// datos, sus derechos y la supresión. Lo que puede hacer depende de dónde
/// esté, y son dos cosas distintas:
///
/// - **Esperando**: ver qué pidió y retirarlo (FR-007). Pedir entrar y
///   arrepentirse son la misma decisión mirada dos veces, y una solicitud que
///   no se puede retirar la deja atada a una espera que ya no quiere.
/// - **Perteneciendo**: salir (FR-025).
///
/// Y cuando no está en ninguno de los dos sitios, **no hay sección**. Una
/// tarjeta que diga «no perteneces a nada» en la pantalla de ajustes de quien
/// nunca pidió nada es ruido; dónde pedir entrar se lo dice la pantalla donde
/// echa de menos su plan, que es donde le hace falta saberlo.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/comunidad/membresia.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/comunidad/terminar_la_pertenencia.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class MiPertenencia extends StatefulWidget {
  const MiPertenencia({
    super.key,
    required this.dondeEsta,
    required this.nombreDeLaComunidad,
    this.alSalir,
    this.alRetirarSolicitud,
    this.alPedirEntrar,
  });

  final DondeEsta? dondeEsta;

  /// Cómo se llama donde está o donde pidió. **El nombre que el entrenador
  /// organizó**, no un identificador: ella eligió por el letrero y por el
  /// letrero tiene que reconocerlo. Nulo si no se pudo leer, y entonces se
  /// dice lo que se sabe sin inventar un nombre.
  final String? nombreDeLaComunidad;

  final Future<void> Function()? alSalir;
  final Future<void> Function()? alRetirarSolicitud;

  /// Abrir el sitio donde elige comunidad y pide entrar. Nulo sin servidor.
  final VoidCallback? alPedirEntrar;

  @override
  State<MiPertenencia> createState() => _MiPertenenciaState();
}

class _MiPertenenciaState extends State<MiPertenencia> {
  bool _retirando = false;
  String? _noSePudoRetirar;

  Future<void> _retirar() async {
    final retirar = widget.alRetirarSolicitud;
    if (retirar == null) return;

    setState(() {
      _retirando = true;
      _noSePudoRetirar = null;
    });

    try {
      await retirar();
      if (mounted) setState(() => _retirando = false);
    } catch (problema) {
      // Lo que no llegó no puede parecer hecho: sigue pedida, y se dice.
      if (!mounted) return;
      setState(() {
        _retirando = false;
        _noSePudoRetirar =
            'No se pudo retirar la solicitud. Sigue pedida ($problema).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final donde = widget.dondeEsta;
    final nombre = widget.nombreDeLaComunidad;
    final texto = Theme.of(context).textTheme;

    return switch (donde) {
      Pertenece() when widget.alSalir != null => Tarjeta(
        key: const Key('mi-pertenencia'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mi comunidad', style: texto.titleMedium),
            const SizedBox(height: Espaciado.minimo),
            Text(
              nombre == null
                  ? 'Perteneces a la comunidad de tu entrenador.'
                  : 'Perteneces a $nombre.',
            ),
            const SizedBox(height: Espaciado.corto),
            TerminarLaPertenencia(quien: null, alTerminar: widget.alSalir!),
          ],
        ),
      ),

      Esperando() => Tarjeta(
        key: const Key('mi-solicitud'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lo que pediste', style: texto.titleMedium),
            const SizedBox(height: Espaciado.minimo),
            Text(
              nombre == null
                  ? 'Pediste entrar en una comunidad y todavía no te han '
                        'contestado.'
                  : 'Pediste entrar en $nombre y todavía no te han contestado.',
            ),
            if (_noSePudoRetirar != null) ...[
              const SizedBox(height: Espaciado.corto),
              Text(
                _noSePudoRetirar!,
                key: const Key('retirar-no-se-pudo'),
                style: texto.bodySmall,
              ),
            ],
            if (widget.alRetirarSolicitud != null) ...[
              const SizedBox(height: Espaciado.corto),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('retirar-solicitud'),
                  onPressed: _retirando ? null : _retirar,
                  icon: const Icon(Icons.undo_outlined),
                  label: const Text('Retirar mi solicitud'),
                ),
              ),
            ],
          ],
        ),
      ),

      // **Ni pertenece ni espera: aquí es donde pide.**
      //
      // Esta rama devolvía nada, y el recorrido del quickstart enseñó por qué
      // no podía: el último paso del alta dice, con todas las letras, «puedes
      // pedirlo más adelante desde Ajustes». Era una promesa que la app no
      // cumplía, y quien la creyera —quien se saltara el paso, o a quien le
      // dijeran que no— no tenía ningún sitio desde donde pedir.
      //
      // Un rechazo no es una prohibición (FR-012) y saltarse el paso no es
      // renunciar (FR-005). Las dos cosas necesitan una puerta, y es esta.
      // `null` no entra aquí a propósito: es «todavía no se sabe», no «no
      // perteneces a nada», y ofrecerle pedir entrar sobre eso sería la
      // lección de la feature 011 repetida.
      (NoHaPedido() || LeDijeronQueNo())
          when widget.alPedirEntrar != null => Tarjeta(
        key: const Key('todavia-sin-comunidad'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mi comunidad', style: texto.titleMedium),
            const SizedBox(height: Espaciado.minimo),
            Text(
              donde is LeDijeronQueNo
                  ? 'Tu solicitud no fue aceptada. Puedes pedir entrar otra '
                        'vez, aquí o con otro entrenador.'
                  : 'Todavía no estás con ningún entrenador. Para recibir un '
                        'plan tienes que pedir entrar en su comunidad.',
            ),
            const SizedBox(height: Espaciado.corto),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('pedir-entrar'),
                onPressed: widget.alPedirEntrar,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Pedir entrar en una comunidad'),
              ),
            ),
          ],
        ),
      ),

      // Sin servidor no hay a quién pedírselo, y entonces no hay sección: un
      // control que no termina lo que empieza es peor que no tenerlo (H12).
      _ => const SizedBox.shrink(),
    };
  }
}
