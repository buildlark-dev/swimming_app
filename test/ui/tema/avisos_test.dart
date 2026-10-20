/// Garantía V12 — hay cuatro tonos, y «guardado» no es uno de error.
///
/// Esta es la prueba que resume para qué existía la decisión D5. Antes de esta
/// feature la app tenía **un solo tono**: de los cincuenta y cuatro usos de
/// color semántico, treinta y cuatro eran de la familia de error, y solo dos
/// sitios eran errores de verdad.
///
/// El peor de todos era este: «Guardado. Se enviará cuando tengas internet»
/// salía en rojo. Es una **buena noticia** —significa que la bandeja de salida
/// de la feature 003 hizo su trabajo y el nadador no perdió nada—, y el nadador
/// la veía con cara de alarma, mojado, al borde de la piscina, después de
/// anotar su sesión.
///
/// Un rojo que sale siempre deja de significar nada. Cuando aparezca uno de
/// verdad, nadie lo mirará.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/nadador/aviso_sincronizacion.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  final hoy = DateTime(2026, 10, 20, 7);

  EstadoNadador estadoCon({required bool pendientes}) {
    final bandeja = _Bandeja(pendientes: pendientes);
    final estado = EstadoNadador(
      sincronizador: Sincronizador(
        registros: _Registros(),
        bandeja: bandeja,
        red: _SinRed(),
        transporte: _Quieto(hoy),
        reloj: () => hoy,
      ),
      reloj: () => hoy,
    );
    estado.abrirComo(const Nadador(id: 'n1', nombre: 'Prueba'));
    return estado;
  }

  Future<void> montar(
    WidgetTester tester,
    EstadoNadador estado, {
    bool oscuro = false,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: oscuro ? Tema.oscuro() : Tema.claro(),
        home: Scaffold(body: AvisoSincronizacion(estado: estado)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('V12 — «guardado, se enviará» es una buena noticia', () {
    for (final oscuro in [false, true]) {
      testWidgets(oscuro ? 'en oscuro' : 'en claro', (tester) async {
        final estado = estadoCon(pendientes: true);
        await estado.sincronizar();
        await montar(tester, estado, oscuro: oscuro);

        final avisos = tester.widgetList<Aviso>(find.byType(Aviso));
        expect(
          avisos,
          hasLength(1),
          reason: 'Con algo pendiente de enviar tiene que haber un aviso, y '
              'uno solo',
        );

        expect(
          avisos.single.tono,
          TonoDeAviso.exito,
          reason: 'Significa que el progreso quedó guardado y que se enviará '
              'solo. El nadador no ha hecho nada mal y no tiene que hacer '
              'nada: pintarlo de rojo le pide una reacción que no existe',
        );
      });
    }

    testWidgets('dice lo mismo que decía antes', (tester) async {
      // El tono cambia; el texto no. La feature 003 eligió esas palabras para
      // no enseñarle al nadador un error de red ni un botón de reintentar.
      final estado = estadoCon(pendientes: true);
      await estado.sincronizar();
      await montar(tester, estado);

      expect(find.text(avisoProgresoGuardado), findsOneWidget);
    });

    testWidgets('sin nada pendiente, no ocupa pantalla', (tester) async {
      final estado = estadoCon(pendientes: false);
      await estado.sincronizar();
      await montar(tester, estado);

      expect(find.byType(Aviso), findsNothing);
    });
  });

  group('los cuatro tonos existen y se distinguen', () {
    test('son cuatro, y ninguno es «rojo para todo»', () {
      expect(TonoDeAviso.values, hasLength(4));
      expect(
        TonoDeAviso.values.map((t) => t.name).toList(),
        ['informativo', 'exito', 'cuidado', 'error'],
      );
    });

    test('cada uno lleva su icono, distinto de los demás', () {
      // FR-015: el color nunca es la única señal.
      expect(
        TonoDeAviso.values.map((t) => t.icono).toSet(),
        hasLength(TonoDeAviso.values.length),
      );
    });

    testWidgets('cada uno tiene su color, en los dos modos', (tester) async {
      for (final oscuro in [false, true]) {
        late ColoresDelDominio colores;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: oscuro ? Tema.oscuro() : Tema.claro(),
            home: Builder(
              builder: (context) {
                colores = context.colores;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();

        expect(
          TonoDeAviso.values.map(colores.deTono).toSet(),
          hasLength(TonoDeAviso.values.length),
        );
      }
    });
  });

  group('el tono se declara siempre, no se hereda', () {
    testWidgets('el aviso exige que le digan de qué tono es', (tester) async {
      // No hay valor por omisión a propósito. Un valor por omisión sería el
      // camino de vuelta a que todo sea del mismo color sin que nadie lo
      // decidiera.
      for (final tono in TonoDeAviso.values) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: Tema.claro(),
            home: Scaffold(body: Aviso(tono: tono, mensaje: 'Mensaje')),
          ),
        );
        await tester.pump();

        expect(tester.widget<Aviso>(find.byType(Aviso)).tono, tono);
      }
    });
  });
}

// ---------------------------------------------------------------------------

class _Bandeja implements BandejaDeSalida {
  _Bandeja({required bool pendientes}) {
    if (pendientes) _envios['r1'] = EnvioPendiente(registroId: 'r1');
  }

  final Map<String, EnvioPendiente> _envios = {};

  @override
  Future<void> encolar(String id) async =>
      _envios[id] = EnvioPendiente(registroId: id);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _envios.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String id) async => _envios[id];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      _envios[envio.registroId] = envio;
}

class _Registros implements RepositorioRegistros {
  final Map<String, RegistroDeSesion> _guardados = {};

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      _guardados.values.toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      _guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => _guardados.clear();
}

class _SinRed implements EstadoDeRed {
  @override
  Future<bool> hayConexion() async => false;

  @override
  Stream<bool> get cambios => const Stream<bool>.empty();
}

class _Quieto implements EnvioDeRegistros {
  _Quieto(this.cuando);

  final DateTime cuando;

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async => cuando;
}
