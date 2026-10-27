import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Reglas de completitud de la sesión (sección 14 y FR-036).
///
/// Una sesión incompleta no puede darse por terminada, y un plan con sesiones
/// incompletas no puede aprobarse.
void main() {
  Sesion sesionCon({
    String objetivoTecnico = 'Mejoramiento técnica de Espalda',
    String objetivoFisiologico = 'Base aeróbica',
    List<FragmentoPendiente> pendientes = const [],
    bool conSeries = true,
  }) {
    return Sesion(
      objetivoTecnico: objetivoTecnico,
      objetivoFisiologico: objetivoFisiologico,
      partes: [
        Parte(
          tipo: TipoParte.inicial,
          series: conSeries ? const [Serie(distancia: 800)] : const [],
          fragmentosPendientes: pendientes,
        ),
        Parte(
          tipo: TipoParte.central,
          series: conSeries ? const [Serie(distancia: 1000)] : const [],
        ),
        Parte(
          tipo: TipoParte.cierre,
          series: conSeries ? const [Serie(distancia: 200)] : const [],
        ),
      ],
    );
  }

  group('sesión completa', () {
    test('con objetivos, tres partes y series está completa', () {
      final sesion = sesionCon();

      expect(sesion.faltas, isEmpty);
      expect(sesion.estaCompleta, isTrue);
    });
  });

  group('datos obligatorios', () {
    test('sin objetivo técnico no está completa', () {
      final sesion = sesionCon(objetivoTecnico: '');

      expect(sesion.estaCompleta, isFalse);
      expect(sesion.faltas.map((f) => f.campo), contains('objetivoTecnico'));
    });

    test('sin objetivo fisiológico no está completa', () {
      final sesion = sesionCon(objetivoFisiologico: '');

      expect(sesion.estaCompleta, isFalse);
      expect(
        sesion.faltas.map((f) => f.campo),
        contains('objetivoFisiologico'),
      );
    });

    test('un objetivo con solo espacios cuenta como vacío', () {
      final sesion = sesionCon(objetivoTecnico: '   ');
      expect(sesion.estaCompleta, isFalse);
    });

    test('faltando ambos objetivos se reportan los dos', () {
      final sesion = sesionCon(objetivoTecnico: '', objetivoFisiologico: '');
      expect(sesion.faltas.length, greaterThanOrEqualTo(2));
    });
  });

  group('sesión sin series', () {
    test('no está completa', () {
      final sesion = sesionCon(conSeries: false);

      expect(sesion.estaCompleta, isFalse);
      expect(sesion.faltas.map((f) => f.campo), contains('series'));
    });
  });

  group('fragmentos pendientes', () {
    test('una sesión con pendientes nunca está completa', () {
      final sesion = sesionCon(
        pendientes: const [
          FragmentoPendiente(
            texto: 'EJERCICIO RARO',
            posicionInicio: 0,
            posicionFin: 14,
            motivo: MotivoPendiente.ejercicioFueraDeBiblioteca,
          ),
        ],
      );

      expect(
        sesion.estaCompleta,
        isFalse,
        reason: 'FR-036: los pendientes impiden dar la sesión por completa',
      );
      expect(sesion.faltas.map((f) => f.campo), contains('pendientes'));
    });

    test('el aviso dice cuántos pendientes quedan', () {
      final sesion = sesionCon(
        pendientes: const [
          FragmentoPendiente(
            texto: 'A',
            posicionInicio: 0,
            posicionFin: 1,
            motivo: MotivoPendiente.terminoDesconocido,
          ),
          FragmentoPendiente(
            texto: 'B',
            posicionInicio: 2,
            posicionFin: 3,
            motivo: MotivoPendiente.ambiguo,
          ),
        ],
      );

      final falta = sesion.faltas.firstWhere((f) => f.campo == 'pendientes');
      expect(falta.descripcion, contains('2'));
    });

    test('aunque tenga pendientes, los metros se siguen calculando', () {
      final sesion = sesionCon(
        pendientes: const [
          FragmentoPendiente(
            texto: 'X',
            posicionInicio: 0,
            posicionFin: 1,
            motivo: MotivoPendiente.terminoDesconocido,
          ),
        ],
      );

      expect(sesion.metros, 2000);
    });
  });

  group('estructura de tres partes', () {
    test('una sesión nueva nace con las tres partes', () {
      final sesion = Sesion();

      expect(sesion.partes, hasLength(3));
      expect(sesion.partes.map((p) => p.tipo), containsAll(TipoParte.values));
    });

    test('reemplazar una parte conserva las otras dos', () {
      final sesion = sesionCon();
      final nueva = sesion.conParte(
        const Parte(tipo: TipoParte.cierre, series: [Serie(distancia: 500)]),
      );

      expect(nueva.partes, hasLength(3));
      expect(nueva.parteDe(TipoParte.cierre).metros, 500);
      expect(nueva.parteDe(TipoParte.inicial).metros, 800);
    });
  });
}
