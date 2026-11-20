/// El control de terminar una pertenencia, para los dos lados (feature 012).
///
/// **Una sola pieza y no dos**, porque la decisión es simétrica (garantía F7):
/// él puede sacarla, ella puede irse, y en los dos casos pasa exactamente lo
/// mismo —deja de poder leerla, y nada de lo que ella escribió se toca—. Dos
/// widgets habrían sido dos sitios donde esa promesa puede divergir, y el día
/// que uno de los dos borrara algo la asimetría estaría escrita en el código
/// en vez de en la spec.
///
/// Lo que cambia entre los dos lados son las palabras, porque lo que pierde
/// cada uno es distinto: él deja de **ver**, ella deja de **recibir**.
///
/// ## Por qué pregunta
///
/// Desde el lado de él no se deshace: para volver atrás ella tendría que pedir
/// entrar otra vez y él volver a aceptar. Un toque no puede costar eso. Y la
/// pregunta dice las dos mitades —lo que se pierde y lo que no— porque «sacar
/// a alguien» suena a borrarlo y no lo es.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class TerminarLaPertenencia extends StatefulWidget {
  const TerminarLaPertenencia({
    super.key,
    required this.quien,
    required this.alTerminar,
  });

  /// A quién se saca, cuando quien mira es el entrenador. **Nulo cuando es
  /// ella quien se va**, y eso es lo que decide las palabras.
  final Nadador? quien;

  final Future<void> Function() alTerminar;

  @override
  State<TerminarLaPertenencia> createState() => _TerminarLaPertenenciaState();
}

class _TerminarLaPertenenciaState extends State<TerminarLaPertenencia> {
  String? _noSePudo;
  bool _enCurso = false;

  bool get _esElEntrenador => widget.quien != null;

  Future<void> _preguntar() async {
    final nombre = widget.quien?.nombre ?? '';

    final seguro = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _esElEntrenador
              ? 'Sacar a $nombre de tu comunidad'
              : 'Salir de la comunidad',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _esElEntrenador
                  ? 'Dejarás de ver lo que $nombre responde, sus planes y su '
                        'progreso.'
                  : 'Dejarás de recibir planes de tu entrenador, y él dejará '
                        'de ver lo que respondes.',
            ),
            const SizedBox(height: Espaciado.corto),
            Text(
              _esElEntrenador
                  ? 'No se borra nada de lo que escribió: sigue siendo suyo, '
                        'y lo sigue viendo ella.'
                  : 'No se borra nada de lo que escribiste: tu historial '
                        'sigue siendo tuyo y lo sigues viendo.',
            ),
            if (!_esElEntrenador) ...[
              const SizedBox(height: Espaciado.corto),
              const Text(
                'Puedes volver a pedir entrar cuando quieras, aquí o con otro '
                'entrenador.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('cancelar-terminar'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-terminar'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_esElEntrenador ? 'Sacar' : 'Salir'),
          ),
        ],
      ),
    );

    if (seguro != true || !mounted) return;

    setState(() {
      _enCurso = true;
      _noSePudo = null;
    });

    try {
      await widget.alTerminar();
      if (mounted) setState(() => _enCurso = false);
    } catch (problema) {
      // **Lo que no llegó no puede parecer hecho.** El control se queda donde
      // estaba, para volver a intentarlo.
      if (!mounted) return;
      setState(() {
        _enCurso = false;
        _noSePudo = _esElEntrenador
            ? 'No se pudo sacarla. Sigue en tu comunidad ($problema).'
            : 'No se pudo salir. Sigues en la comunidad ($problema).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final problema = _noSePudo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (problema != null) ...[
          Aviso(
            tono: TonoDeAviso.cuidado,
            icono: Icons.cloud_off_outlined,
            claveDelMensaje: const Key('terminar-no-se-pudo'),
            mensaje: problema,
          ),
          const SizedBox(height: Espaciado.corto),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('terminar-pertenencia'),
            onPressed: _enCurso ? null : _preguntar,
            icon: const Icon(Icons.logout_outlined),
            label: Text(
              _esElEntrenador
                  ? 'Sacar de mi comunidad'
                  : 'Salir de la comunidad',
            ),
          ),
        ),
      ],
    );
  }
}
