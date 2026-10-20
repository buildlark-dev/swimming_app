/// Garantía V3 — un componente no decide, toma.
///
/// Las garantías V1 y V2 ya vigilan que no haya colores ni tamaños de letra
/// escritos a mano en `lib/`, y los componentes son archivos de `lib/`. Lo que
/// esas dos no ven es lo demás: un `EdgeInsets.all(14)`, un `width: 70`, un
/// radio inventado. Un componente con una medida propia es un componente que se
/// desalinea del resto en cuanto alguien cambia un token.
///
/// **La consecuencia que importa**: si un componente necesita un valor que no
/// está en los tokens, **falta un token**. No se añade el valor al componente.
/// Ya pasó una vez, con el tamaño de los iconos: el botón lo necesitaba, y lo
/// que faltaba era `Espaciado.iconoEnLinea`, no un 18 suelto.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  final carpeta = Directory('lib/ui/componentes');

  List<File> componentes() => carpeta
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('V3 — los componentes no llevan medidas propias', () {
    /// Un número suelto dentro de una medida.
    ///
    /// Caza `EdgeInsets.all(14)`, `width: 70`, `size: 18`, `circular(10)`. No
    /// caza `Espaciado.corto`, que es lo que queremos ver, ni `width: 2` del
    /// grosor de un indicador, que no es una medida del sistema.
    final patron = RegExp(
      r'(EdgeInsets\.\w+\(\s*[0-9]|'
      r'(?:width|height|size|spacing|runSpacing|radius|elevation)'
      r':\s*[0-9]{2,}|'
      r'circular\(\s*[0-9])',
    );

    test('ninguno escribe una medida a mano', () {
      final infracciones = <String>[];

      for (final archivo in componentes()) {
        final lineas = archivo.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final limpia = lineas[i].trimLeft();
          if (limpia.startsWith('//')) continue;
          if (patron.hasMatch(lineas[i])) {
            infracciones.add(
              '${archivo.path.replaceAll(r'\', '/')}:${i + 1}  '
              '${lineas[i].trim()}',
            );
          }
        }
      }

      expect(
        infracciones,
        isEmpty,
        reason: 'Un componente toma sus medidas de `Espaciado`. Si la que '
            'necesita no está, **falta un token**: se añade allí, no aquí.\n\n'
            '${infracciones.join('\n')}',
      );
    });

    test('ninguno conoce la paleta', () {
      // Los colores se leen del tema, que es lo que hace que el modo oscuro
      // funcione sin tocar un solo componente.
      final infracciones = <String>[];

      for (final archivo in componentes()) {
        if (archivo.readAsStringSync().contains('tema/paleta.dart')) {
          infracciones.add(archivo.path.replaceAll(r'\', '/'));
        }
      }

      expect(
        infracciones,
        isEmpty,
        reason: 'Un componente lee de `Theme.of(context)`, no de `Paleta`.\n\n'
            '${infracciones.join('\n')}',
      );
    });

    test('la prueba no pasa por vacía', () {
      // Si la carpeta estuviera vacía o el patrón no cazara nada, los dos
      // casos de arriba aprobarían sin mirar nada.
      expect(componentes(), hasLength(greaterThanOrEqualTo(6)));
      expect(patron.hasMatch('padding: EdgeInsets.all(14),'), isTrue);
      expect(patron.hasMatch('width: 70,'), isTrue);
      expect(patron.hasMatch('padding: EdgeInsets.all(Espaciado.normal),'),
          isFalse);
    });
  });

  group('el aviso', () {
    Widget conTema(Widget hijo, {bool oscuro = false}) => MaterialApp(
          theme: oscuro ? Tema.oscuro() : Tema.claro(),
          home: Scaffold(body: hijo),
        );

    /// Monta sobre un árbol limpio.
    ///
    /// `MaterialApp` **anima** el cambio de tema con un `AnimatedTheme` de 200
    /// ms. Si se cambia el tema sobre un árbol que ya existe y se bombea una
    /// sola vez, lo que se lee es el color de antes, a mitad de la animación.
    /// Costó un diagnóstico: parecía que el componente llevaba el color
    /// escrito, y lo que pasaba era que la prueba miraba demasiado pronto.
    ///
    /// Tirar el árbol primero evita la animación entera.
    Future<void> montar(WidgetTester tester, Widget app) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app);
      await tester.pump();
    }

    testWidgets('cada tono lleva su propio icono', (tester) async {
      // FR-015: el color **nunca** es la única señal. Quien no distinga
      // colores tiene que reconocer el tono igual.
      final iconos = <IconData>{};

      for (final tono in TonoDeAviso.values) {
        await montar(
          tester,
          conTema(Aviso(tono: tono, mensaje: 'Un mensaje cualquiera')),
        );

        final icono = tester.widget<Icon>(find.byType(Icon).first);
        iconos.add(icono.icon!);
      }

      expect(
        iconos,
        hasLength(TonoDeAviso.values.length),
        reason: 'Dos tonos con el mismo icono se distinguen solo por el '
            'color, y eso deja fuera a quien no lo distingue',
      );
    });

    testWidgets('el color del tono sale del tema, no del aviso', (tester) async {
      // El mismo aviso en claro y en oscuro tiene que cambiar de color sin que
      // nadie lo configure. Si no cambia, el color está escrito en el
      // componente.
      final colores = <Color>[];

      for (final oscuro in [false, true]) {
        await montar(
          tester,
          conTema(
            const Aviso(tono: TonoDeAviso.exito, mensaje: 'Guardado'),
            oscuro: oscuro,
          ),
        );
        colores.add(tester.widget<Icon>(find.byType(Icon).first).color!);
      }

      expect(colores.first, isNot(colores.last));
    });

    testWidgets('muestra el mensaje y el título que le dan', (tester) async {
      await tester.pumpWidget(
        conTema(
          const Aviso(
            tono: TonoDeAviso.cuidado,
            titulo: 'Sesión incompleta',
            mensaje: 'Faltan 200 m sin zona asignada',
          ),
        ),
      );

      expect(find.text('Sesión incompleta'), findsOneWidget);
      expect(find.text('Faltan 200 m sin zona asignada'), findsOneWidget);
    });
  });

  group('los demás componentes se pintan', () {
    // No es una prueba de aspecto: es que ninguno lance al construirse. Un
    // componente que no se puede montar no lo descubre nadie hasta la pantalla
    // que lo usa.
    final casos = <String, Widget>{
      'tarjeta': const Tarjeta(child: Text('Contenido')),
      'tarjeta pulsable': Tarjeta(alPulsar: () {}, child: const Text('Toca')),
      'campo': const Campo(etiqueta: 'Nombre'),
      'campo de opciones': CampoDeOpciones<String>(
        etiqueta: 'Categoría',
        opciones: const ['Formativo', 'Precompetitivo'],
        nombreDe: (v) => v,
        alCambiar: (_) {},
      ),
      'opciones en fila': OpcionesEnFila<int>(
        opciones: const [0, 1, 2],
        nombreDe: (v) => '$v',
        alElegir: (_) {},
      ),
      'botón principal': BotonPrincipal(etiqueta: 'Entrar', alPulsar: () {}),
      'botón trabajando': BotonPrincipal(
        etiqueta: 'Entrar',
        alPulsar: () {},
        trabajando: true,
      ),
      'cabecera': const CabeceraSeccion(titulo: 'Parte inicial', cifra: '400 m'),
      'cabecera sin cifra': const CabeceraSeccion(titulo: 'Distribución'),
      'estado vacío': const EstadoVacio(
        icono: Icons.event_busy_outlined,
        titulo: 'Todavía no tienes un plan asignado',
        queHacer: 'Cuando tu entrenador te asigne uno, aparecerá aquí.',
      ),
    };

    casos.forEach((nombre, componente) {
      testWidgets(nombre, (tester) async {
        for (final oscuro in [false, true]) {
          // Árbol limpio en cada modo, por lo mismo que arriba: si no, el
          // segundo se pinta con el tema del primero y el oscuro no se prueba.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MaterialApp(
              theme: oscuro ? Tema.oscuro() : Tema.claro(),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: componente,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        }
      });
    });
  });

  group('un botón que trabaja no se puede pulsar dos veces', () {
    testWidgets('mientras trabaja, no responde', (tester) async {
      // Pulsar dos veces «Entregar» es entregar dos veces.
      var pulsaciones = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: Scaffold(
            body: BotonPrincipal(
              etiqueta: 'Entregar',
              alPulsar: () => pulsaciones++,
              trabajando: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(pulsaciones, 0);
    });

    testWidgets('cuando no trabaja, sí', (tester) async {
      var pulsaciones = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: Scaffold(
            body: BotonPrincipal(
              etiqueta: 'Entregar',
              alPulsar: () => pulsaciones++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(pulsaciones, 1);
    });
  });
}
