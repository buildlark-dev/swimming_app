/// **Una regla, dos pantallas** (FR-012).
///
/// Lo que a ella le falta por contestar y lo que él lee como huecos tienen que
/// ser el mismo número, porque son la misma cosa. Si cada pantalla lo contara
/// por su cuenta, el día que una cambiara la otra seguiría diciendo lo de
/// antes, y ninguno de los dos sabría cuál creer.
///
/// Se comprueba sobre la fuente además de sobre el valor: que coincidan hoy es
/// necesario, pero lo que de verdad lo sostiene es que **salgan del mismo
/// sitio**. Dos cálculos que hoy dan lo mismo son dos cálculos que mañana
/// pueden no darlo.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/progreso_en_el_macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  final hoy = DateTime(2026, 11, 18);

  test('el número sale de un solo sitio', () {
    final progreso = ProgresoEnElMacrociclo(
      mesociclos: [
        Plan(
          id: 'p1',
          nombre: 'Mesociclo 1',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
          estado: EstadoPlan.publicado,
          versionMetodologia: '3.6.0',
          sesiones: [
            Sesion(id: 'hecha', microcicloId: 'm1', fecha: DateTime(2026, 11, 9)),
            Sesion(id: 'dijoNo', microcicloId: 'm1', fecha: DateTime(2026, 11, 11)),
            Sesion(id: 'muda', microcicloId: 'm1', fecha: DateTime(2026, 11, 13)),
          ],
        ),
      ],
      registros: [
        RegistroDeSesion(
          nadadorId: 'n-ana',
          planId: 'p1',
          sesionId: 'hecha',
          versionDePlan: '1',
          realizada: true,
          registradoEn: hoy,
        ),
        RegistroDeSesion(
          nadadorId: 'n-ana',
          planId: 'p1',
          sesionId: 'dijoNo',
          versionDePlan: '1',
          realizada: false,
          registradoEn: hoy,
        ),
      ],
      hoy: hoy,
    );

    // Lo que ella ve y lo que él lee es esto, y es uno solo.
    expect(progreso.pendientes.map((s) => s.id), ['muda']);
    expect(
      progreso.pendientes.map((s) => s.id).toSet(),
      progreso.sinContestar,
      reason:
          'lo pendiente ES lo que no contestó. Si fueran dos cálculos, un día '
          'dirían cosas distintas en dos pantallas',
    );
  });

  test('y ninguna pantalla se lo calcula por su cuenta', () {
    // El cerrojo de verdad: nadie filtra `hechas` a mano fuera del dominio.
    // Así nació el defecto —un getter correcto al lado de otro que no lo era—
    // y así volvería.
    final hallazgos = <String>[];
    var archivosLeidos = 0;

    for (final carpeta in [Directory('lib/ui'), Directory('lib/datos')]) {
      if (!carpeta.existsSync()) continue;

      for (final entrada in carpeta.listSync(recursive: true)) {
        if (entrada is! File || !entrada.path.endsWith('.dart')) continue;
        archivosLeidos++;

        final lineas = entrada
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .split('\n');

        for (var i = 0; i < lineas.length; i++) {
          final limpia = lineas[i].trimLeft();
          if (limpia.startsWith('//') || limpia.startsWith('///')) continue;

          // **Lo que se prohíbe es rehacer «lo pendiente», que se escribe
          // negado.** Preguntar en positivo —«¿la hizo?», para pintar el
          // tick— es una pregunta legítima y `hechas` es el conjunto correcto
          // para contestarla. Lo que no puede hacer una pantalla es deducir
          // por su cuenta qué le falta por contestar, porque entonces hay dos
          // reglas y un día dicen cosas distintas.
          //
          // El defecto nació así: un getter correcto (`sinContestar`) al lado
          // de otro que restaba mal (`pendientes`, excluyendo solo `hechas`).
          if (lineas[i].contains('!progreso.hechas.contains') ||
              lineas[i].contains('!hechas.contains') ||
              lineas[i].contains('!progreso.dijoQueNo.contains') ||
              lineas[i].contains('!dijoQueNo.contains')) {
            hallazgos.add('${entrada.path}:${i + 1} -> ${lineas[i].trim()}');
          }
        }
      }
    }

    expect(
      archivosLeidos,
      greaterThan(20),
      reason: 'se leyeron $archivosLeidos archivos: la prueba estaría vacía',
    );
    expect(
      hallazgos,
      isEmpty,
      reason:
          'alguien está decidiendo fuera del dominio qué cuenta como '
          'pendiente:\n${hallazgos.join('\n')}',
    );
  });
}
