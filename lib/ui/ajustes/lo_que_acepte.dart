/// Lo que acepté: el texto de **esa** versión, no el vigente.
///
/// La feature 006 versionó los textos para que cambiarlos no reescriba lo que
/// alguien ya aceptó (FR-018 de aquella). Mostrar aquí el texto de hoy sería
/// deshacer eso: diría que la persona aceptó algo que no leyó.
///
/// Si el archivo de esa versión ya no está en la app, se dice. Es mejor que
/// enseñar otro texto con la fecha de aquel.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:natacion_app/dominio/consentimiento/constancia.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class LoQueAcepte extends StatelessWidget {
  const LoQueAcepte({super.key, required this.perfil, this.constancia});

  final Perfil perfil;

  /// La del consentimiento, cuando hay. En una cuenta de adulto no existe, y
  /// no se insinúa que falte algo.
  final ConstanciaDeConsentimiento? constancia;

  @override
  Widget build(BuildContext context) {
    final terminos = perfil.terminos;
    final consentimiento = constancia;

    return Tarjeta(
      key: const Key('ajustes-lo-que-acepte'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(titulo: 'Lo que acepté'),
          const SizedBox(height: Espaciado.normal),
          if (terminos == null)
            const Text(
              'No consta que hayas aceptado los términos. Si entraste antes '
              'de que existieran, se te pedirán la próxima vez.',
            )
          else
            _Aceptado(
              titulo: 'Términos y condiciones',
              version: terminos.version,
              cuando: terminos.aceptadaEn,
              rutaDelTexto: 'assets/terminos/texto_${terminos.version}.md',
              quienAcepto: 'Los aceptaste tú',
            ),
          if (consentimiento != null) ...[
            const SizedBox(height: Espaciado.amplio),
            _Aceptado(
              titulo: 'Consentimiento de tus datos',
              version: consentimiento.versionDelTexto,
              cuando: consentimiento.otorgadoEn,
              rutaDelTexto: consentimiento.versionDelTexto == null
                  ? null
                  : 'assets/consentimiento/'
                        'texto_${consentimiento.versionDelTexto}.md',
              quienAcepto: consentimiento.vigente
                  ? 'Lo autorizó tu acudiente'
                  : 'Lo autorizó tu acudiente, y está revocado',
            ),
          ],
        ],
      ),
    );
  }
}

class _Aceptado extends StatelessWidget {
  const _Aceptado({
    required this.titulo,
    required this.version,
    required this.cuando,
    required this.rutaDelTexto,
    required this.quienAcepto,
  });

  final String titulo;
  final String? version;
  final DateTime? cuando;
  final String? rutaDelTexto;
  final String quienAcepto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: textos.titleSmall),
        const SizedBox(height: Espaciado.minimo),
        Text(
          [
            quienAcepto,
            if (version != null) 'versión $version',
            if (cuando != null)
              'el ${cuando!.day}/${cuando!.month}/${cuando!.year}',
          ].join(' · '),
          style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        if (rutaDelTexto != null) ...[
          const SizedBox(height: Espaciado.corto),
          OutlinedButton.icon(
            key: Key('ajustes-leer-$titulo'),
            onPressed: () => _abrirTexto(context, titulo, rutaDelTexto!),
            icon: const Icon(Icons.article_outlined),
            label: const Text('Leer el texto que acepté'),
          ),
        ] else ...[
          const SizedBox(height: Espaciado.corto),
          Text(
            'No consta qué versión del texto se mostró.',
            style: textos.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _abrirTexto(
    BuildContext context,
    String titulo,
    String ruta,
  ) async {
    String texto;
    try {
      texto = await rootBundle.loadString(ruta);
    } catch (_) {
      // **Esa versión ya no viaja con la app.** Se dice, en lugar de mostrar
      // el texto vigente con la fecha de aquel.
      texto =
          'El texto de esa versión ya no viene con la app. Lo que consta '
          'es qué versión aceptaste y cuándo, y eso no cambia.';
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(texto)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
