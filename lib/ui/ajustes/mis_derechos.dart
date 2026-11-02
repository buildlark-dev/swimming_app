/// Mis derechos: saber qué se guarda, y llevármelo.
///
/// **Esto es lo que esta feature viene a arreglar.** `DerechosDelTitular` está
/// en el dominio desde la feature 004, con sus pruebas, y ninguna pantalla lo
/// construía: los tres derechos que la Ley 1581 reconoce existían en el código
/// y no existían para la persona.
///
/// Lo que se guarda se dice **en frases** (H25): un acudiente tiene derecho a
/// saber qué hay sobre su hijo, y «qué hay» no se responde con un JSON.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class MisDerechos extends StatefulWidget {
  const MisDerechos({
    super.key,
    required this.derechos,
    required this.nadadorId,
  });

  final DerechosDelTitular? derechos;

  /// Nulo en una cuenta sin ficha de nadador —la del entrenador, por ejemplo—:
  /// entonces no hay registros ni asignaciones suyas que exportar.
  final String? nadadorId;

  @override
  State<MisDerechos> createState() => _MisDerechosState();
}

class _MisDerechosState extends State<MisDerechos> {
  List<String>? _queSeGuarda;
  String? _problema;
  bool _cargando = false;

  Future<void> _verQueSeGuarda() async {
    final derechos = widget.derechos;
    final nadadorId = widget.nadadorId;
    if (derechos == null || nadadorId == null) return;

    setState(() {
      _cargando = true;
      _problema = null;
    });

    try {
      final que = await derechos.queSeGuardaDe(nadadorId);
      if (!mounted) return;
      setState(() {
        _queSeGuarda =
            que?.enPalabras ?? const ['No hay nada guardado sobre ti todavía.'];
      });
    } on FalloDeDatos catch (e) {
      if (mounted) setState(() => _problema = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _exportar() async {
    final derechos = widget.derechos;
    final nadadorId = widget.nadadorId;
    if (derechos == null || nadadorId == null) return;

    try {
      final datos = await derechos.exportar(nadadorId);

      // **Nada de esto va a un registro ni a una traza** (H26, garantía A17 de
      // la 006). Va al portapapeles, que es del usuario y de nadie más.
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(datos)),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tus datos quedaron copiados. Pégalos donde quieras guardarlos.',
          ),
        ),
      );
    } on FalloDeDatos catch (e) {
      if (mounted) setState(() => _problema = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final sinDatosDeNadador =
        widget.derechos == null || widget.nadadorId == null;

    return Tarjeta(
      key: const Key('ajustes-mis-derechos'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(titulo: 'Mis datos y mis derechos'),
          const SizedBox(height: Espaciado.corto),
          Text(
            'La Ley 1581 te da derecho a saber qué se guarda sobre ti, a '
            'llevártelo y a pedir que se elimine.',
            style: textos.bodySmall,
          ),
          const SizedBox(height: Espaciado.normal),
          if (sinDatosDeNadador)
            const Aviso(
              claveDelMensaje: Key('ajustes-sin-datos-de-nadador'),
              tono: TonoDeAviso.informativo,
              icono: Icons.info_outline,
              mensaje:
                  'Esta cuenta no tiene ficha de nadador, así que no hay '
                  'sesiones ni respuestas tuyas guardadas. Tus datos de '
                  'cuenta están arriba.',
            )
          else ...[
            OutlinedButton.icon(
              key: const Key('ajustes-que-se-guarda'),
              onPressed: _cargando ? null : _verQueSeGuarda,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver qué se guarda sobre mí'),
            ),
            if (_queSeGuarda != null) ...[
              const SizedBox(height: Espaciado.normal),
              for (final frase in _queSeGuarda!)
                Padding(
                  padding: const EdgeInsets.only(bottom: Espaciado.minimo),
                  child: Text('· $frase', style: textos.bodyMedium),
                ),
            ],
            const SizedBox(height: Espaciado.normal),
            OutlinedButton.icon(
              key: const Key('ajustes-exportar'),
              onPressed: _exportar,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Llevarme mis datos'),
            ),
          ],
          if (_problema != null) ...[
            const SizedBox(height: Espaciado.normal),
            Aviso(
              tono: TonoDeAviso.error,
              icono: Icons.error_outline,
              mensaje: _problema!,
            ),
          ],
        ],
      ),
    );
  }
}
