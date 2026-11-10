/// M30 a M35 — el reajuste es un acto del entrenador, y se avisa una vez.
///
/// Lo que estas pruebas fijan, en orden de lo que más cuesta si se pierde:
///
/// - **la app no reajusta sola** (M30), por clara que parezca la adherencia;
/// - las versiones nuevas nacen en borrador: **todavía no le han llegado al
///   nadador** (M35), y hay que firmarlas;
/// - un reajuste que mueve tres mesociclos es **un acto y un aviso** (M32), no
///   tres;
/// - y se puede decir en qué versión va cada bloque sin que el entrenador lo
///   calcule (M33).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/reajuste.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

import '../../ui/macrociclo/ayuda_macrociclo.dart';

void main() {
  late RepositoriosDelMacrociclo repos;

  setUp(() {
    repos = RepositoriosDelMacrociclo();
  });

  /// Un macrociclo firmado y entregado, que es lo único reajustable.
  Future<MacrocicloGuardado> entregado() async {
    final guardado = await macrocicloGuardado(repos);

    final firmado = await firmarElMacrociclo(
      macrociclo: guardado.macrociclo,
      mesociclos: guardado.mesociclos,
      planes: repos.planes,
      macrociclos: repos.macrociclos,
      hoy: hoyDePrueba,
    );

    final entregado = await entregarElMacrociclo(
      macrociclo: firmado,
      mesociclos: [
        for (final m in guardado.mesociclos)
          m.copiarCon(estado: EstadoPlan.aprobado),
      ],
      planes: repos.planes,
      asignaciones: repos.asignaciones,
      macrociclos: repos.macrociclos,
      hoy: hoyDePrueba,
    );

    final mesociclos = <Plan>[];
    for (final id in entregado.mesociclos) {
      final plan = await repos.planes.obtener(id);
      if (plan != null) mesociclos.add(plan);
    }

    return MacrocicloGuardado(
      macrociclo: entregado,
      mesociclos: mesociclos,
    );
  }

  Future<MacrocicloReajustado> reajustar(
    MacrocicloGuardado macro,
    Set<String> cuales,
  ) => reajustarElMacrociclo(
    macrociclo: macro.macrociclo,
    mesociclos: macro.mesociclos,
    cualesSeReajustan: cuales,
    planes: repos.planes,
    macrociclos_: repos.macrociclos,
    hoy: hoyDePrueba.add(const Duration(days: 30)),
  );

  group('M30 — reajusta el entrenador y nadie más', () {
    test('hay que decir qué mesociclos se mueven', () async {
      // No hay disparador automático, y no haberlo es la feature: la sección 4
      // paso 8 es criterio suyo, no una condición que la app evalúe.
      final macro = await entregado();

      await expectLater(
        reajustar(macro, const {}),
        throwsA(isA<FalloDeDatos>()),
      );
    });

    test('un mesociclo que no es de este macrociclo se rechaza', () async {
      final macro = await entregado();

      await expectLater(
        reajustar(macro, {'plan-de-otro'}),
        throwsA(isA<FalloDeDatos>()),
      );
    });

    test('con la lista de mesociclos incompleta no se reajusta', () async {
      // Reajustar sobre una lista a medias dejaría el macrociclo apuntando a
      // mesociclos que nadie leyó.
      final macro = await entregado();

      await expectLater(
        reajustarElMacrociclo(
          macrociclo: macro.macrociclo,
          mesociclos: macro.mesociclos.take(2).toList(),
          cualesSeReajustan: {macro.mesociclos.first.id!},
          planes: repos.planes,
          macrociclos_: repos.macrociclos,
          hoy: hoyDePrueba,
        ),
        throwsA(isA<FalloDeDatos>()),
      );
    });
  });

  group('M31 — lo que cambia recibe versión nueva', () {
    test('el mesociclo reajustado estrena versión y apunta a la anterior', () async {
      final macro = await entregado();
      final cual = macro.mesociclos[1];

      final reajustado = await reajustar(macro, {cual.id!});

      expect(reajustado.versionesNuevas, hasLength(1));
      expect(reajustado.versionesNuevas.single.versionAnteriorId, cual.id);
      expect(reajustado.versionesNuevas.single.id, isNot(cual.id));
    });

    test('los que no se tocaron se quedan como estaban', () async {
      final macro = await entregado();
      final cual = macro.mesociclos[1];

      final reajustado = await reajustar(macro, {cual.id!});

      expect(reajustado.mesociclos[0].id, macro.mesociclos[0].id);
      expect(reajustado.mesociclos[2].id, macro.mesociclos[2].id);
      expect(reajustado.mesociclos[1].id, isNot(cual.id));
    });

    test('el macrociclo pasa a apuntar a las versiones nuevas', () async {
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      final enElAlmacen = await repos.macrociclos.obtener(
        macro.macrociclo.id!,
      );
      expect(enElAlmacen!.mesociclos, reajustado.macrociclo.mesociclos);
      expect(enElAlmacen.mesociclos[1], isNot(macro.mesociclos[1].id));
    });

    test('la versión anterior sigue entregada y legible', () async {
      // FR-030: lo anterior sigue trazable. Es lo que hace que los registros
      // del nadador sigan teniendo dónde vivir.
      final macro = await entregado();
      final cual = macro.mesociclos[1];

      await reajustar(macro, {cual.id!});

      final anterior = await repos.planes.obtener(cual.id!);
      expect(anterior!.estado, EstadoPlan.publicado);
      expect(anterior.sesiones, isNotEmpty);
    });
  });

  group('M35 — todavía no le ha llegado al nadador', () {
    test('la versión nueva nace en borrador', () async {
      // Lo que sale de un reajuste es contenido automático recién hecho: pasa
      // la auditoría de la sección 16 y lleva su firma, como todo lo demás.
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      expect(
        reajustado.versionesNuevas.single.estado,
        EstadoPlan.borrador,
      );
    });

    test('y se puede revisar y firmar con lo que ya existe', () async {
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      final revision = revisarElMacrociclo(
        macrociclo: reajustado.macrociclo,
        mesociclos: reajustado.mesociclos,
      );

      expect(
        revision.sePuedeFirmar,
        isTrue,
        reason: revision.impedimentos.join('; '),
      );
    });
  });

  group('M32 — un acto, un aviso', () {
    test('reajustar tres mesociclos deja un solo aviso', () async {
      final macro = await entregado();

      final reajustado = await reajustar(
        macro,
        {for (final m in macro.mesociclos) m.id!},
      );

      expect(reajustado.versionesNuevas, hasLength(3));
      // Uno, no tres.
      expect(reajustado.macrociclo.ultimoReajuste, isNotNull);
      expect(
        reajustado.macrociclo.ultimoReajuste!.bloquesAjustados,
        [1, 2, 3],
      );
    });

    test('y el nadador lo lee en una frase, sin jerga', () async {
      final macro = await entregado();
      final reajustado = await reajustar(
        macro,
        {macro.mesociclos[0].id!, macro.mesociclos[2].id!},
      );

      final frase = reajustado.aviso.comoSeLeElNadador;

      expect(frase, 'Tu entrenador ajustó los bloques 1 y 3 de tu plan.');
      expect(frase.toLowerCase(), isNot(contains('mesociclo')));
      expect(frase.toLowerCase(), isNot(contains('versión')));
      expect(frase.toLowerCase(), isNot(contains('macrociclo')));
    });

    test('con uno solo, la frase va en singular', () async {
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      expect(
        reajustado.aviso.comoSeLeElNadador,
        'Tu entrenador ajustó el bloque 2 de tu plan.',
      );
    });

    test('el aviso queda guardado, para que lo vea cuando abra', () async {
      // Si viviera solo en memoria, el nadador se enteraría únicamente si
      // tuviera la app abierta en ese momento.
      final macro = await entregado();
      await reajustar(macro, {macro.mesociclos[1].id!});

      final enElAlmacen = await repos.macrociclos.obtener(
        macro.macrociclo.id!,
      );
      expect(enElAlmacen!.ultimoReajuste, isNotNull);
      expect(enElAlmacen.ultimoReajuste!.bloquesAjustados, [2]);
    });

    test('un reajuste nuevo sustituye el aviso, no lo acumula', () async {
      // Lo que el nadador necesita saber es que su entrenador ajustó una
      // parte, no el historial de todas las veces.
      final macro = await entregado();
      final primero = await reajustar(macro, {macro.mesociclos[0].id!});

      final segundo = await reajustarElMacrociclo(
        macrociclo: primero.macrociclo,
        mesociclos: primero.mesociclos,
        cualesSeReajustan: {primero.mesociclos[2].id!},
        planes: repos.planes,
        macrociclos_: repos.macrociclos,
        hoy: hoyDePrueba.add(const Duration(days: 40)),
      );

      expect(segundo.aviso.bloquesAjustados, [3]);
    });
  });

  group('M35, FR-037 — firmar y entregar el reajuste', () {
    test('entregarlo asigna la versión nueva al nadador', () async {
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      final entregadas = await firmarYEntregarElReajuste(
        reajustado: reajustado,
        planes: repos.planes,
        asignaciones: repos.asignaciones,
        hoy: hoyDePrueba,
      );

      expect(entregadas.single.estado, EstadoPlan.publicado);

      final suyas = await repos.asignaciones.deNadador('n-ana');
      expect(suyas.map((a) => a.planId), contains(entregadas.single.id));
    });

    test('y retira la anterior: el nadador trabaja con una', () async {
      // Con las dos asignadas vería el bloque 2 por duplicado, y no sabría
      // cuál es el que vale.
      final macro = await entregado();
      final anterior = macro.mesociclos[1];
      final reajustado = await reajustar(macro, {anterior.id!});

      await firmarYEntregarElReajuste(
        reajustado: reajustado,
        planes: repos.planes,
        asignaciones: repos.asignaciones,
        hoy: hoyDePrueba,
      );

      final suyas = await repos.asignaciones.deNadador('n-ana');
      expect(suyas.map((a) => a.planId), isNot(contains(anterior.id)));
      expect(suyas, hasLength(3));
    });

    test('el macrociclo sigue entregado, no retrocede', () async {
      // **Lo que firmó entonces sigue firmado.** Devolverlo a `aprobado`
      // sería retroceder en el ciclo de vida, y las reglas lo rechazan.
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      await firmarYEntregarElReajuste(
        reajustado: reajustado,
        planes: repos.planes,
        asignaciones: repos.asignaciones,
        hoy: hoyDePrueba,
      );

      final enElAlmacen = await repos.macrociclos.obtener(
        macro.macrociclo.id!,
      );
      expect(enElAlmacen!.estado, EstadoPlan.publicado);
    });

    test('una versión que no pasa la auditoría no se entrega', () async {
      // Ni ella ni las demás: el reajuste no llega a medias.
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      final roto = MacrocicloReajustado(
        macrociclo: reajustado.macrociclo,
        mesociclos: reajustado.mesociclos,
        versionesNuevas: [
          reajustado.versionesNuevas.single.copiarCon(sesiones: const []),
        ],
        aviso: reajustado.aviso,
      );

      await expectLater(
        firmarYEntregarElReajuste(
          reajustado: roto,
          planes: repos.planes,
          asignaciones: repos.asignaciones,
          hoy: hoyDePrueba,
        ),
        throwsA(isA<FalloDeDatos>()),
      );

      // Y el nadador sigue con las tres de antes, ninguna nueva.
      final suyas = await repos.asignaciones.deNadador('n-ana');
      expect(suyas, hasLength(3));
      expect(
        suyas.map((a) => a.planId),
        contains(macro.mesociclos[1].id),
      );
    });
  });

  group('M33 — en qué versión va cada bloque', () {
    test('sin reajustes, todos en la primera', () async {
      final macro = await entregado();

      final versiones = await enQueVersionVa(
        mesociclos: macro.mesociclos,
        planes: repos.planes,
      );

      expect(versiones, hasLength(3));
      for (final version in versiones) {
        expect(version.cuantasVersiones, 1);
        expect(version.seReajusto, isFalse);
        expect(version.comoSeLee, contains('sin reajustes'));
      }
    });

    test('el reajustado va en la segunda, y se dice', () async {
      // **Sin que el entrenador lo calcule** (M33): la pregunta «¿en qué plan
      // está este nadador?» se contesta sola.
      final macro = await entregado();
      final reajustado = await reajustar(macro, {macro.mesociclos[1].id!});

      final versiones = await enQueVersionVa(
        mesociclos: reajustado.mesociclos,
        planes: repos.planes,
      );

      expect(versiones[0].cuantasVersiones, 1);
      expect(versiones[1].cuantasVersiones, 2);
      expect(versiones[1].comoSeLee, 'Bloque 2: versión 2');
      expect(versiones[2].cuantasVersiones, 1);
    });

    test('tres reajustes del mismo bloque son tres versiones', () async {
      final macro = await entregado();
      var actual = macro;

      for (var i = 0; i < 2; i++) {
        final reajustado = await reajustarElMacrociclo(
          macrociclo: actual.macrociclo,
          mesociclos: actual.mesociclos,
          cualesSeReajustan: {actual.mesociclos[1].id!},
          planes: repos.planes,
          macrociclos_: repos.macrociclos,
          hoy: hoyDePrueba.add(Duration(days: 30 * (i + 1))),
        );

        // **Se firma el reajuste, no el macrociclo.** Pasarlo por
        // `firmarElMacrociclo` lo devolvería a `aprobado`, que es retroceder
        // en el ciclo de vida: lo que firmó entonces sigue firmado. Lo
        // destapó esta misma prueba en el primer intento.
        await firmarYEntregarElReajuste(
          reajustado: reajustado,
          planes: repos.planes,
          asignaciones: repos.asignaciones,
          hoy: hoyDePrueba,
        );

        final frescos = <Plan>[];
        for (final id in reajustado.macrociclo.mesociclos) {
          frescos.add((await repos.planes.obtener(id))!);
        }
        actual = MacrocicloGuardado(
          macrociclo: reajustado.macrociclo,
          mesociclos: frescos,
        );
      }

      final versiones = await enQueVersionVa(
        mesociclos: actual.mesociclos,
        planes: repos.planes,
      );

      expect(versiones[1].cuantasVersiones, 3);
    });
  });
}
