/// Guardar, firmar y entregar el macrociclo. Tres actos, uno cada uno.
///
/// Vive en el dominio y no en una pantalla aunque hable con repositorios: las
/// interfaces son del dominio (principio II, `repositorios.dart` no menciona
/// ningún tipo de Firestore), y el cerrojo M10 —**nada existe antes de la
/// confirmación**— tiene que poder comprobarse sobre el almacenamiento y no
/// sobre una pantalla. Con esto dentro de un `State` solo se podría comprobar
/// pintando, y la feature 008 aprendió dos veces que lo que una pantalla no
/// enseña no dice nada sobre lo que existe.
///
/// **Las sesiones se escriben aquí, explícitamente.** `guardarBorrador` de un
/// plan guarda el documento del plan y no su subcolección de sesiones: en
/// Firestore las sesiones son documentos aparte y solo el editor las escribía,
/// una a una. Un macrociclo tiene cuarenta y dos: a mano no se guardan.
library;

import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Lo que quedó guardado al confirmar.
class MacrocicloGuardado {
  const MacrocicloGuardado({
    required this.macrociclo,
    required this.mesociclos,
  });

  /// Ya con identificador.
  final Macrociclo macrociclo;

  /// Los mesociclos guardados, cada uno con su id, el del macrociclo y sus
  /// sesiones con los identificadores que les asignó el almacenamiento.
  final List<Plan> mesociclos;
}

/// Guarda el macrociclo derivado. **Este es el único sitio que escribe algo**,
/// y solo se llama después de que el entrenador confirme (M10, FR-002,
/// SC-010).
///
/// El orden no es casual. `Macrociclo` guarda ids de planes y un plan no tiene
/// id hasta que se guarda, así que:
///
/// 1. los mesociclos, con sus sesiones, para que tengan id;
/// 2. el macrociclo, con esos ids;
/// 3. y de vuelta a cada mesociclo para decirle de qué macrociclo es.
///
/// El tercer paso es una escritura más por mesociclo. Se podría evitar
/// generando los identificadores en el cliente, pero eso obligaría a que toda
/// implementación de `RepositorioPlanes` supiera inventar ids, y son siete
/// escrituras de más en un acto que se hace una vez por temporada.
Future<MacrocicloGuardado> guardarElMacrociclo({
  required MacrocicloDerivado derivado,
  required RepositorioPlanes planes,
  required RepositorioMacrociclos macrociclos,
}) async {
  final guardados = <Plan>[];

  for (final mesociclo in derivado.mesociclos) {
    final planId = await planes.guardarBorrador(mesociclo);

    // **Las sesiones las escribe `guardarBorrador`**, y se vuelven a leer para
    // recoger el identificador que el almacenamiento les asignó: es el que los
    // registros del nadador van a referenciar, y de ahí que un reajuste que lo
    // cambie le deje el historial en blanco (M34).
    //
    // Esta función las escribía aparte, porque cuando se escribió guardar un
    // plan **no** guardaba sus sesiones —un defecto de la feature 008 que la
    // 009 encontró y arregló—. Con el arreglo puesto, escribirlas aquí otra
    // vez las duplicaría: las sesiones del motor llegan sin id, así que cada
    // escritura crearía documentos nuevos y el nadador vería la semana
    // repetida.
    final conSusIds = await planes.obtener(planId);
    guardados.add(conSusIds ?? mesociclo.copiarCon(id: planId));
  }

  final macrociclo = derivado.macrocicloConLosIds([
    for (final mesociclo in guardados) mesociclo.id!,
  ]);
  final macrocicloId = await macrociclos.guardarBorrador(macrociclo);

  final conMacrociclo = <Plan>[];
  for (final mesociclo in guardados) {
    final actualizado = mesociclo.copiarCon(macrocicloId: macrocicloId);
    await planes.guardarBorrador(actualizado);
    conMacrociclo.add(actualizado);
  }

  return MacrocicloGuardado(
    macrociclo: macrociclo.copiarCon(id: macrocicloId),
    mesociclos: List.unmodifiable(conMacrociclo),
  );
}

/// Por qué todavía no se puede firmar: la auditoría de cada mesociclo más la
/// comprobación de que ninguno quedó sin firmar.
class RevisionDelMacrociclo {
  const RevisionDelMacrociclo({
    required this.porMesociclo,
    required this.impedimentos,
  });

  /// La auditoría de la sección 16 de cada mesociclo, en orden. **La misma
  /// auditoría que cualquier otro plan**, no una más ligera (M13).
  final List<ResultadoAuditoria> porMesociclo;

  final List<ImpedimentoDelMacrociclo> impedimentos;

  /// Verdadero si los mesociclos pasan la auditoría y se puede firmar.
  bool get sePuedeFirmar =>
      impedimentos.isEmpty &&
      porMesociclo.every((r) => r.apruebaSinBloqueos);
}

/// Revisa el macrociclo entero antes de firmarlo.
RevisionDelMacrociclo revisarElMacrociclo({
  required Macrociclo macrociclo,
  required List<Plan> mesociclos,
}) => RevisionDelMacrociclo(
  porMesociclo: [for (final plan in mesociclos) Auditoria().evaluar(plan)],
  // **Faltan, no «están en borrador».** Antes de firmar, sus mesociclos están
  // en borrador por definición: eso es lo que se va a firmar. Lo que impide
  // firmar es que alguno de los que el macrociclo nombra no esté delante.
  impedimentos: mesociclosQueFaltan(
    macrociclo: macrociclo,
    mesociclos: mesociclos,
  ),
);

/// Firmar el macrociclo. **Un acto, por muchos mesociclos que tenga** (M15).
///
/// Mueve cada mesociclo a `aprobado` con su instantánea de auditoría, y el
/// macrociclo detrás. Si alguno no pasa la auditoría **no se firma ninguno**:
/// un macrociclo medio firmado no es un estado, es una avería.
Future<Macrociclo> firmarElMacrociclo({
  required Macrociclo macrociclo,
  required List<Plan> mesociclos,
  required RepositorioPlanes planes,
  required RepositorioMacrociclos macrociclos,
  required DateTime hoy,
}) async {
  final revision = revisarElMacrociclo(
    macrociclo: macrociclo,
    mesociclos: mesociclos,
  );

  if (!revision.sePuedeFirmar) {
    throw const FalloDeDatos(
      'Hay mesociclos que todavía no pasan la auditoría: el macrociclo no se '
      'firma a medias',
    );
  }

  for (var i = 0; i < mesociclos.length; i++) {
    final firmado = mesociclos[i].copiarCon(
      estado: EstadoPlan.aprobado,
      fechaAprobacion: hoy,
    );
    final auditado = revision.porMesociclo[i];

    await planes.guardarAprobado(firmado, <String, dynamic>{
      'cumpleTodo': auditado.apruebaSinBloqueos,
      'criterios': {
        for (final criterio in auditado.criterios) criterio.id: criterio.cumple,
      },
    });
  }

  final firmado = macrociclo.copiarCon(estado: EstadoPlan.aprobado);
  await macrociclos.guardarAprobado(firmado, <String, dynamic>{
    'mesociclos': {
      for (var i = 0; i < mesociclos.length; i++)
        mesociclos[i].id!: revision.porMesociclo[i].apruebaSinBloqueos,
    },
    'firmadoEn': hoy.toIso8601String(),
  });

  return firmado;
}

/// Entregar el macrociclo. **Firmar no es entregar** (M17), y la entrega es
/// **todo o nada** (M16).
///
/// Un nadador viendo cuatro de siete mesociclos es peor que viendo ninguno: no
/// sabría que le faltan tres. Así que se publican y se asignan todos, y si
/// alguno falla se dice que la entrega no se hizo en lugar de dejarla a
/// medias.
Future<Macrociclo> entregarElMacrociclo({
  required Macrociclo macrociclo,
  required List<Plan> mesociclos,
  required RepositorioPlanes planes,
  required RepositorioAsignaciones asignaciones,
  required RepositorioMacrociclos macrociclos,
  required DateTime hoy,
}) async {
  if (macrociclo.estado != EstadoPlan.aprobado) {
    throw const FalloDeDatos(
      'Solo se entrega un macrociclo firmado: firmar no es entregar',
    );
  }

  final publicados = <Plan>[];

  try {
    for (final mesociclo in mesociclos) {
      // **Solo el estado**: lo firmado no se reescribe (FR-025).
      await planes.publicar(mesociclo.id!);
      final publicado = mesociclo.copiarCon(estado: EstadoPlan.publicado);
      await asignaciones.asignar(
        Asignacion(
          planId: mesociclo.id!,
          nadadorId: macrociclo.nadadorId,
          asignadaEn: hoy,
        ),
      );
      publicados.add(publicado);
    }
  } on Object {
    // **Se deshace lo entregado.** Retirar la asignación es lo que le quita
    // el mesociclo de la vista al nadador; sus registros no se tocan, que es
    // justo lo que `retirar` promete desde la feature 004.
    for (final publicado in publicados) {
      await asignaciones.retirar(publicado.id!, macrociclo.nadadorId);
    }
    rethrow;
  }

  await macrociclos.publicar(macrociclo.id!);
  return macrociclo.copiarCon(estado: EstadoPlan.publicado);
}
