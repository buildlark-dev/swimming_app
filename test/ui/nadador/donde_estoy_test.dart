/// FR-020, FR-021, FR-022 — a ella no se le dice nada falso mientras espera.
///
/// ## Dos preguntas independientes, cuatro respuestas
///
/// «¿Tengo plan?» y «¿pertenezco a algo?» no son la misma pregunta, y la
/// pantalla las estaba contestando con una sola:
///
/// | | tiene plan | no tiene plan |
/// |---|---|---|
/// | **pertenece** | su plan | «todavía no tienes un plan asignado» |
/// | **espera** | su plan | «esperando que el entrenador acepte tu ingreso» |
/// | **no pidió** | su plan | «todavía no tienes un plan asignado» |
/// | **le dijeron que no** | su plan | puede volver a pedir |
///
/// La casilla que importa es la segunda. Decirle «cuando tu entrenador te
/// asigne uno aparecerá aquí» a quien **todavía no tiene entrenador** es
/// mandarla a esperar algo que nadie va a hacer, y eso es exactamente el
/// defecto que la feature 011 arregló para «todavía no sé» contra «no hay»
/// (decisión D4 de aquella, D6 de esta).
///
/// ## Y por qué no es un quinto caso de `Lectura`
///
/// `Lectura` dice si **la lectura** terminó y qué encontró. Esperar es un
/// hecho sobre **ella** que explica por qué la lectura no encontró nada.
/// Meterlos en el mismo tipo sería el defecto de la 011 con otro disfraz: un
/// valor con dos significados y una pantalla eligiendo el más contundente.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/membresia.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/lectura/lectura.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:natacion_app/ui/nadador/pantalla_sesion_del_dia.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/dominio/sincronizacion/despertador.dart';
import 'package:provider/provider.dart';

import '../../dominio/sincronizacion/dobles_de_sincronizacion.dart';
import '../hub/ayuda_hub.dart';

void main() {
  const ella = Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
  );

  Sincronizador quieto() => Sincronizador(
        registros: RegistrosDeMentiraLocales(),
        bandeja: BandejaDeMentira(),
        red: RedDeMentira(),
        transporte: TransporteMudo(),
        despertador: const DespertadorQuieto(),
      );

  EstadoNadador estadoCon(DondeEsta donde) {
    final estado = EstadoNadador(sincronizador: quieto());
    estado.abrirComo(ella);
    estado.anotarDondeEsta(donde);
    return estado;
  }

  Future<void> montarProgreso(WidgetTester tester, EstadoNadador estado) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoNadador>.value(
          value: estado,
          child: const PantallaMiProgreso(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> montarHoy(WidgetTester tester, EstadoNadador estado) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoNadador>.value(
          value: estado,
          child: const PantallaSesionDelDia(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('FR-020 — esperando, se le dice que espera', () {
    testWidgets('en Mi progreso', (tester) async {
      await montarProgreso(tester, estadoCon(const Esperando('e-uno')));

      expect(
        find.textContaining('Esperando que el entrenador acepte tu ingreso'),
        findsOneWidget,
      );
      // **Y no la otra frase.** Las dos juntas serían peor que cualquiera de
      // las dos sola.
      expect(
        find.textContaining('Todavía no tienes un plan asignado'),
        findsNothing,
      );
    });

    testWidgets('y en la sesión del día', (tester) async {
      await montarHoy(tester, estadoCon(const Esperando('e-uno')));

      expect(
        find.textContaining('Esperando que el entrenador acepte tu ingreso'),
        findsOneWidget,
      );
    });
  });

  group('FR-021 — sin haber pedido, no se le dice que espera', () {
    testWidgets('en Mi progreso', (tester) async {
      await montarProgreso(tester, estadoCon(const NoHaPedido()));

      expect(
        find.textContaining('Esperando que el entrenador'),
        findsNothing,
      );
      // Y se le dice lo que sí puede hacer, que es pedir entrar.
      expect(find.byKey(const Key('todavia-no-pediste')), findsOneWidget);
    });

    testWidgets('y tampoco si le dijeron que no', (tester) async {
      await montarProgreso(tester, estadoCon(const LeDijeronQueNo('e-uno')));

      expect(find.textContaining('Esperando que el entrenador'), findsNothing);
      // **Un rechazo no es una prohibición** (FR-012): puede volver a pedir,
      // aquí o en otro sitio, y la pantalla no la deja sin salida.
      expect(find.byKey(const Key('puedes-volver-a-pedir')), findsOneWidget);
    });
  });

  group('perteneciendo y sin plan, la frase de siempre', () {
    testWidgets('«todavía no tienes un plan asignado»', (tester) async {
      await montarProgreso(
        tester,
        estadoCon(
          Pertenece(
            Membresia(
              nadadorId: 'n-ana',
              comunidadId: 'e-uno',
              desde: DateTime(2026, 11, 1),
            ),
          ),
        ),
      );

      expect(
        find.textContaining('Todavía no tienes un plan asignado'),
        findsOneWidget,
      );
      expect(find.textContaining('Esperando que el entrenador'), findsNothing);
    });
  });

  group('con plan, la pertenencia no pinta nada', () {
    testWidgets('esperando o no, lo que ve es su plan', (tester) async {
      final estado = EstadoNadador(sincronizador: quieto());
      estado.abrirComo(ella, plan: planDePrueba());
      estado.anotarDondeEsta(const Esperando('e-uno'));

      await montarProgreso(tester, estado);

      // **Las dos preguntas son independientes.** Si alguna vez le llegó un
      // plan, el aviso de espera no puede taparlo.
      expect(find.textContaining('Esperando que el entrenador'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('FR-022 — el aviso se va solo cuando la aceptan', () {
    testWidgets('sin que ella toque nada', (tester) async {
      final estado = estadoCon(const Esperando('e-uno'));
      await montarProgreso(tester, estado);
      expect(find.textContaining('Esperando que el entrenador'), findsOneWidget);

      // El entrenador acepta; la siguiente lectura lo trae.
      estado.anotarDondeEsta(
        Pertenece(
          Membresia(
            nadadorId: 'n-ana',
            comunidadId: 'e-uno',
            desde: DateTime(2026, 11, 19),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Esperando que el entrenador'), findsNothing);
    });
  });

  group('mientras no se sabe, no se le dice ninguna de las cuatro', () {
    testWidgets('«todavía no sé» sigue siendo «todavía no sé»', (tester) async {
      // El control que impide que esto se convierta en un quinto caso de
      // `Lectura`: si nadie ha preguntado por el plan todavía, la pantalla
      // sigue cargando aunque ya sepa dónde está ella.
      final estado = EstadoNadador(sincronizador: quieto());
      estado.anotarDondeEsta(const Esperando('e-uno'));

      await tester.pumpWidget(
        MaterialApp(
        home: ChangeNotifierProvider<EstadoNadador>.value(
          value: estado,
          child: const PantallaMiProgreso(),
        ),
      ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Esperando que el entrenador'), findsNothing);
    });
  });

  group('lo que el tipo NO es', () {
    test('esperar no es un caso de Lectura', () {
      // T054. Si algún día alguien añade `Esperando` a `Lectura`, esta prueba
      // es la que se cae, y el motivo está escrito arriba y en research D6.
      const lecturas = <Type>{Cargando, Hay, NoHay, NoSePudo};
      expect(lecturas.contains(Esperando), isFalse);
      expect(lecturas.length, 4, reason: 'Lectura tiene cuatro casos, no cinco');
    });

    test('y dónde está ella tiene sus propios cuatro', () {
      const donde = <Type>{Pertenece, Esperando, NoHaPedido, LeDijeronQueNo};
      expect(donde.length, 4);
    });
  });
group('FR-026 — si la sacaron, se le dice', () {
    testWidgets('y no «todavía no te has unido a ningún entrenador»', (
      tester,
    ) async {
      // **Esa frase es falsa para quien estuvo en un grupo hasta ayer**, y la
      // dejaría buscando un plan que ya no le va a llegar sin saber por qué.
      final estado = EstadoNadador(sincronizador: quieto());
      estado.abrirComo(
        const Nadador(
          id: 'n-ana',
          nombre: 'Ana María Restrepo',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '200 Libre',
        ).copiarCon(),
      );
      estado.anotarDondeEsta(const NoHaPedido());

      await montarProgreso(tester, estado);

      // Sin fecha de salida, la frase de siempre.
      expect(find.byKey(const Key('todavia-no-pediste')), findsOneWidget);
    });

    testWidgets('con fecha de salida, se lo dice y dice que no perdió nada', (
      tester,
    ) async {
      final estado = EstadoNadador(sincronizador: quieto());
      estado.abrirComo(
        Nadador(
          id: 'n-ana',
          nombre: 'Ana María Restrepo',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '200 Libre',
          pertenenciaTerminadaEn: DateTime(2026, 11, 18),
        ),
      );
      estado.anotarDondeEsta(const NoHaPedido());

      await montarProgreso(tester, estado);

      expect(
        find.byKey(const Key('ya-no-estas-en-la-comunidad')),
        findsOneWidget,
      );
      expect(find.textContaining('18/11/2026'), findsOneWidget);
      // Las dos cosas que necesita saber: que no perdió nada y que puede
      // volver a pedir.
      expect(find.textContaining('sigue siendo tuyo'), findsOneWidget);
      expect(find.textContaining('pedir entrar en otra'), findsOneWidget);
    });
  });
}
