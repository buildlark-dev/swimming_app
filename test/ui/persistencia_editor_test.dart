import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';

import '../dominio/notacion/ayuda_pruebas.dart';

/// FR-047: la sesión se guarda con su texto original, sus series
/// interpretadas, sus fragmentos pendientes y el origen de cada serie.
void main() {
  late RepositorioSesionesMemoria repositorio;
  late EstadoEditor estado;

  setUp(() {
    repositorio = RepositorioSesionesMemoria();
    estado = EstadoEditor(
      biblioteca: cargarBibliotecaReal(),
      repositorio: repositorio,
      planId: 'plan-1',
    );
  });

  group('guardar', () {
    test('sin repositorio el editor funciona pero no guarda', () async {
      final sinDestino = EstadoEditor(biblioteca: cargarBibliotecaReal());

      expect(sinDestino.puedeGuardar, isFalse);
      expect(await sinDestino.guardar(), isFalse);
    });

    test(
      'con repositorio la sesión se guarda y recibe identificador',
      () async {
        estado.cambiarObjetivoTecnico('Técnica de espalda');
        estado.cambiarObjetivoFisiologico('Base aeróbica');
        estado.escribirParte(TipoParte.inicial, '4x100 AL / 2\'');

        expect(await estado.guardar(), isTrue);
        expect(estado.sesion.id, isNotNull);
      },
    );

    test('la sesión guardada conserva los metros', () async {
      estado.escribirParte(TipoParte.inicial, '4x100 AL / 2\'');
      await estado.guardar();

      final guardadas = await repositorio.obtenerDePlan('plan-1');
      expect(guardadas.single.metros, 400);
    });

    test('conserva el texto original tal como se escribió', () async {
      const texto = '300 Nado Libre (A1)';
      estado.escribirParte(TipoParte.inicial, texto);
      await estado.guardar();

      final guardadas = await repositorio.obtenerDePlan('plan-1');
      expect(guardadas.single.parteDe(TipoParte.inicial).textoOriginal, texto);
    });

    test('conserva los fragmentos pendientes', () async {
      estado.escribirParte(TipoParte.inicial, '200 EJERCICIO INVENTADO');
      await estado.guardar();

      final guardadas = await repositorio.obtenerDePlan('plan-1');
      expect(guardadas.single.todosLosPendientes, isNotEmpty);
    });

    test('conserva el origen de una serie corregida a mano', () async {
      estado.escribirParte(TipoParte.inicial, '4x100 N');
      estado.corregirSerie(TipoParte.inicial, 0, 'distancia', valorEntero: 150);
      await estado.guardar();

      final guardadas = await repositorio.obtenerDePlan('plan-1');
      final serie = guardadas.single.parteDe(TipoParte.inicial).series.first;

      expect(serie.origen, OrigenDato.corregidoAMano);
      expect(serie.distancia, 150);
      expect(serie.metros, 600);
    });

    test('conserva la zona asignada', () async {
      estado.escribirParte(TipoParte.inicial, '4x100 N');
      estado.asignarZona(TipoParte.inicial, 0, Zona.at);
      await estado.guardar();

      final guardadas = await repositorio.obtenerDePlan('plan-1');
      expect(
        guardadas.single.parteDe(TipoParte.inicial).series.first.zona,
        Zona.at,
      );
    });

    test('una sesión incompleta también se guarda: es un borrador', () async {
      estado.escribirParte(TipoParte.inicial, '200 N');

      expect(estado.sesion.estaCompleta, isFalse);
      expect(
        await estado.guardar(),
        isTrue,
        reason:
            'Lo que no se puede es aprobar un plan con sesiones '
            'incompletas, pero guardar un borrador sí',
      );
    });
  });

  group('la corrección manual sobrevive a la reinterpretación', () {
    test('no se pierde al seguir escribiendo en la misma parte', () {
      estado.escribirParte(TipoParte.inicial, '4x100 N');
      estado.corregirSerie(TipoParte.inicial, 0, 'distancia', valorEntero: 150);

      // El entrenador sigue escribiendo: se reinterpreta toda la parte.
      estado.escribirParte(TipoParte.inicial, '4x100 N AL');

      final serie = estado.sesion.parteDe(TipoParte.inicial).series.first;
      expect(
        serie.distancia,
        150,
        reason: 'FR-035: la corrección manual prevalece',
      );
      expect(serie.implementos, contains(Implemento.aletas));
    });
  });
}
