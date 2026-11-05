/// El reajuste: un acto del entrenador, varias versiones debajo (M30 a M35).
///
/// **La sección 4, paso 8: controlar y reajustar.** Es lo que hace que el plan
/// sea un modelo y no un calendario. Y es **suyo**: la app no reajusta por su
/// cuenta por clara que parezca la adherencia (M30, FR-029). Aquí no hay
/// ningún disparador automático, y que no lo haya es la feature.
///
/// Lo que pasa cuando reajusta:
///
/// 1. cada mesociclo que cambia recibe una **versión nueva**, por el linaje
///    que ya existe desde la feature 001 (M31, FR-031);
/// 2. el macrociclo pasa a apuntar a esas versiones, en **una escritura**;
/// 3. y el nadador se entera **una vez**, no una por mesociclo (M32, FR-032).
///
/// Las versiones nuevas nacen en `borrador`: **todavía no le han llegado al
/// nadador**. Tienen que pasar la auditoría de la sección 16 y la firma del
/// entrenador, igual que cualquier otro contenido (M35, FR-036, FR-037). Por
/// eso esto devuelve lo que hay que firmar en lugar de firmarlo.
///
/// Lo que el nadador ya anotó no se toca: `registrosDelLinaje` lo encuentra
/// leyendo hacia atrás (M34, FR-035).
library;

import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Lo que queda después de reajustar, antes de firmar.
class MacrocicloReajustado {
  const MacrocicloReajustado({
    required this.macrociclo,
    required this.mesociclos,
    required this.versionesNuevas,
    required this.aviso,
  });

  /// Ya apuntando a las versiones nuevas, con el aviso puesto.
  final Macrociclo macrociclo;

  /// Los mesociclos como quedan: los que no se tocaron y las versiones nuevas
  /// de los que sí, **en el orden de la preparación**.
  final List<Plan> mesociclos;

  /// Solo las versiones nuevas. Son las que hay que revisar y firmar.
  final List<Plan> versionesNuevas;

  final ReajusteAnunciado aviso;
}

/// Reajusta los mesociclos que el entrenador señale. **Un acto.**
///
/// `cualesSeReajustan` son identificadores de mesociclo. Si viene vacío no se
/// hace nada: un reajuste que no mueve nada no es un reajuste, y anunciarlo le
/// diría al nadador que su entrenador cambió algo que no cambió.
Future<MacrocicloReajustado> reajustarElMacrociclo({
  required Macrociclo macrociclo,
  required List<Plan> mesociclos,
  required Set<String> cualesSeReajustan,
  required RepositorioPlanes planes,
  required RepositorioMacrociclos macrociclos_,
  required DateTime hoy,
}) async {
  if (cualesSeReajustan.isEmpty) {
    throw const FalloDeDatos(
      'Un reajuste que no mueve ningún mesociclo no es un reajuste',
    );
  }

  final faltan = mesociclosQueFaltan(
    macrociclo: macrociclo,
    mesociclos: mesociclos,
  );
  if (faltan.isNotEmpty) {
    // Reajustar con la lista incompleta dejaría el macrociclo apuntando a
    // mesociclos que nadie leyó.
    throw FalloDeDatos(
      'No se pudieron leer todos los mesociclos: ${faltan.join('; ')}',
    );
  }

  final desconocidos = cualesSeReajustan.difference(
    mesociclos.map((m) => m.id).whereType<String>().toSet(),
  );
  if (desconocidos.isNotEmpty) {
    throw FalloDeDatos(
      'Esos mesociclos no son de este macrociclo: ${desconocidos.join(', ')}',
    );
  }

  final comoQuedan = <Plan>[];
  final nuevas = <Plan>[];
  final bloques = <int>[];

  for (var i = 0; i < mesociclos.length; i++) {
    final mesociclo = mesociclos[i];

    if (!cualesSeReajustan.contains(mesociclo.id)) {
      comoQuedan.add(mesociclo);
      continue;
    }

    // `crearVersionDesde` se niega a versionar un borrador y arrastra el
    // origen: es justo el comportamiento que esto necesita, y por eso no hay
    // un linaje nuevo para los mesociclos.
    final version = await planes.crearVersionDesde(mesociclo.id!);

    comoQuedan.add(version);
    nuevas.add(version);
    // El nadador cuenta los bloques desde 1, que es como los ve.
    bloques.add((mesociclo.ordenEnElMacrociclo ?? i) + 1);
  }

  final aviso = ReajusteAnunciado(hechoEn: hoy, bloquesAjustados: bloques);

  // Una escritura, por muchos mesociclos que se hayan movido (M32).
  await macrociclos_.anunciarElReajuste(
    macrociclo.id!,
    mesociclos: [for (final mesociclo in comoQuedan) mesociclo.id!],
    aviso: aviso,
  );

  return MacrocicloReajustado(
    macrociclo: macrociclo.copiarCon(
      mesociclos: [for (final mesociclo in comoQuedan) mesociclo.id!],
      ultimoReajuste: aviso,
    ),
    mesociclos: List.unmodifiable(comoQuedan),
    versionesNuevas: List.unmodifiable(nuevas),
    aviso: aviso,
  );
}

/// Firma y entrega **lo que cambió**, dejando el macrociclo donde está.
///
/// **El macrociclo no se vuelve a firmar.** Es un error fácil de cometer —lo
/// cometí— y la primera prueba que reajustó dos veces lo destapó: pasar el
/// macrociclo entregado por `firmarElMacrociclo` lo devuelve a `aprobado`, que
/// es retroceder en el ciclo de vida. Las reglas de Firestore lo rechazarían, y
/// con razón: lo que el entrenador firmó entonces sigue firmado. Lo que se
/// firma ahora son las versiones nuevas de los mesociclos que movió.
///
/// Es **un acto** (M32): o se firman y entregan todas o ninguna. Y la
/// asignación de la versión anterior se retira, para que el nadador no tenga
/// dos versiones del mismo bloque. Retirar **no borra sus registros**: lo que
/// él escribió es suyo, y `registrosDelLinaje` lo sigue encontrando.
Future<List<Plan>> firmarYEntregarElReajuste({
  required MacrocicloReajustado reajustado,
  required RepositorioPlanes planes,
  required RepositorioAsignaciones asignaciones,
  required DateTime hoy,
}) async {
  final auditadas = [
    for (final version in reajustado.versionesNuevas)
      Auditoria().evaluar(version),
  ];

  if (auditadas.any((r) => !r.apruebaSinBloqueos)) {
    throw const FalloDeDatos(
      'Hay versiones nuevas que no pasan la auditoría: el reajuste no se '
      'entrega a medias',
    );
  }

  final entregadas = <Plan>[];

  for (var i = 0; i < reajustado.versionesNuevas.length; i++) {
    final version = reajustado.versionesNuevas[i];
    final auditada = auditadas[i];

    await planes.guardarAprobado(
      version.copiarCon(
        estado: EstadoPlan.aprobado,
        fechaAprobacion: hoy,
      ),
      <String, dynamic>{
        'cumpleTodo': auditada.apruebaSinBloqueos,
        'criterios': {
          for (final criterio in auditada.criterios)
            criterio.id: criterio.cumple,
        },
      },
    );

    final publicada = version.copiarCon(estado: EstadoPlan.publicado);
    await planes.guardarAprobado(publicada, const <String, dynamic>{});
    await asignaciones.asignar(
      Asignacion(
        planId: version.id!,
        nadadorId: reajustado.macrociclo.nadadorId,
        asignadaEn: hoy,
      ),
    );

    // La versión anterior deja de estar asignada: el nadador trabaja con una.
    final anterior = version.versionAnteriorId;
    if (anterior != null) {
      await asignaciones.retirar(anterior, reajustado.macrociclo.nadadorId);
    }

    entregadas.add(publicada);
  }

  return List.unmodifiable(entregadas);
}

/// En qué versión de cada mesociclo está el nadador (M33, FR-033).
///
/// **Sin que el entrenador lo calcule.** La pregunta «¿en qué plan está este
/// nadador?» se contesta con el macrociclo más la versión actual de cada uno
/// de sus mesociclos, y eso es lo que devuelve esto: por bloque, cuántas
/// versiones lleva y cuál es la de ahora.
class VersionDeCadaMesociclo {
  const VersionDeCadaMesociclo({
    required this.bloque,
    required this.mesocicloId,
    required this.cuantasVersiones,
  });

  /// Desde 1, como el nadador lo ve.
  final int bloque;
  final String mesocicloId;

  /// 1 si nunca se reajustó.
  final int cuantasVersiones;

  bool get seReajusto => cuantasVersiones > 1;

  String get comoSeLee => seReajusto
      ? 'Bloque $bloque: versión $cuantasVersiones'
      : 'Bloque $bloque: sin reajustes';
}

/// Recorre el linaje de cada mesociclo para contar sus versiones.
Future<List<VersionDeCadaMesociclo>> enQueVersionVa({
  required List<Plan> mesociclos,
  required RepositorioPlanes planes,
}) async {
  final porBloque = <VersionDeCadaMesociclo>[];

  for (var i = 0; i < mesociclos.length; i++) {
    final mesociclo = mesociclos[i];

    var cuantas = 1;
    final vistos = <String>{if (mesociclo.id != null) mesociclo.id!};
    var anterior = mesociclo.versionAnteriorId;

    while (anterior != null && vistos.add(anterior) && cuantas < 50) {
      cuantas++;
      anterior = (await planes.obtener(anterior))?.versionAnteriorId;
    }

    porBloque.add(
      VersionDeCadaMesociclo(
        bloque: (mesociclo.ordenEnElMacrociclo ?? i) + 1,
        mesocicloId: mesociclo.id ?? '',
        cuantasVersiones: cuantas,
      ),
    );
  }

  return List.unmodifiable(porBloque);
}
