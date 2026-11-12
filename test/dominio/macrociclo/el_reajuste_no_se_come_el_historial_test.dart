/// M34, FR-035, SC-008 — **la callada.**
///
/// Un reajuste crea una versión nueva del mesociclo. Lo que el nadador ya
/// anotó apunta a `sesionId`, y los `RegistroDeSesion` se indexan además por
/// `planId` y por versión. Así que una versión nueva con identificadores de
/// sesión nuevos, o un lector que solo mire el plan nuevo, **le deja el
/// historial en blanco y no falla nada**: todas las escrituras devuelven bien,
/// la pantalla se pinta, y las sesiones que nadó aparecen sin marcar.
///
/// Por eso lo que se comprueba aquí es que los registros sigan siendo
/// **alcanzables**, no que la escritura saliera bien. Esa distinción es el
/// contenido de M34.
///
/// **Una corrección sobre el diagnóstico, porque importa.** Al planificar la
/// feature se anotó que `RepositorioPlanesFirestore.crearVersionDesde` «le da
/// identificadores nuevos a las sesiones» porque escribía cada una con
/// `sesion.copiarCon(id: null)`. Leído de corrido lo parece; **no era así**:
/// `Sesion.copiarCon` resuelve `id ?? this.id`, así que pasar nulo conserva el
/// identificador. Esa mitad del defecto no existía, y el control negativo de
/// T071 lo destapó al quedarse verde con la mutación puesta.
///
/// Lo que sí fallaba, y es lo que estas pruebas fijan:
///
/// - **el lector**: los registros se guardan contra el plan en el que se
///   escribieron, y después de versionar nadie los iba a buscar. El progreso
///   leía el plan nuevo y encontraba cero;
/// - **y las dos implementaciones no coincidían**: la de memoria escribía el
///   mapa de planes a mano, así que las sesiones de la versión nueva no
///   quedaban registradas y `obtenerDePlan` del plan nuevo devolvía vacío.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/progreso_en_el_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/registros_del_linaje.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

void main() {
  final hoy = DateTime(2026, 11, 18);

  late RepositorioSesionesMemoria sesiones;
  late RepositorioPlanesMemoria planes;
  late _RegistrosEnMemoria registros;

  setUp(() {
    sesiones = RepositorioSesionesMemoria();
    planes = RepositorioPlanesMemoria(sesiones: sesiones);
    registros = _RegistrosEnMemoria();
  });

  Sesion sesion(DateTime fecha) => Sesion(microcicloId: 'mc-1', fecha: fecha);

  Plan mesociclo() => Plan(
    nombre: 'Mesociclo 1: Acumulación',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    faseAtr: FaseAtr.acumulacion,
    fechaInicio: DateTime(2026, 11, 2),
    fechaFin: DateTime(2026, 11, 29),
    macrocicloId: 'macro-1',
    ordenEnElMacrociclo: 0,
    versionMetodologia: '3.6.0',
    origen: OrigenPlan.automatico,
    sesiones: [
      sesion(DateTime(2026, 11, 2)),
      sesion(DateTime(2026, 11, 4)),
      sesion(DateTime(2026, 11, 6)),
    ],
  );

  /// Guarda el mesociclo, lo firma, y el nadador marca dos sesiones.
  Future<Plan> unMesocicloVividoAMedias() async {
    final id = await planes.guardarBorrador(mesociclo());
    final guardado = (await planes.obtener(id))!;

    await planes.guardarAprobado(
      guardado.copiarCon(estado: EstadoPlan.aprobado),
      const {},
    );

    final firmado = (await planes.obtener(id))!;

    for (final sesion in firmado.sesiones.take(2)) {
      await registros.guardar(
        RegistroDeSesion(
          nadadorId: 'n-ana',
          planId: id,
          sesionId: sesion.id!,
          versionDePlan: firmado.versionMetodologia ?? '',
          realizada: true,
          registradoEn: hoy,
          rpePercibido: 7,
          observaciones: 'Me costó el último 100.',
        ),
      );
    }

    return firmado;
  }

  group('antes de reajustar, el historial está donde tiene que estar', () {
    test('las dos sesiones marcadas se ven como hechas', () async {
      // El punto de partida: sin esto, todo lo demás pasaría en vacío.
      final vivido = await unMesocicloVividoAMedias();

      final progreso = ProgresoEnElMacrociclo(
        mesociclos: [vivido],
        registros: await registros.obtenerDePlan('n-ana', vivido.id!),
        hoy: hoy,
      );

      expect(progreso.hechas, hasLength(2));
      expect(progreso.adherencia.descripcion, '2 de 3');
    });
  });

  group('después de reajustar, los registros siguen alcanzables', () {
    test('la versión nueva conserva los identificadores de sesión', () async {
      // **La mitad que convierte el reajuste en pérdida de datos.** Si las
      // sesiones de la versión nueva estrenan identificador, lo que el nadador
      // anotó deja de apuntar a nada que esté en su plan.
      final vivido = await unMesocicloVividoAMedias();

      final nueva = await planes.crearVersionDesde(vivido.id!);
      final guardada = (await planes.obtener(nueva.id!))!;

      expect(
        guardada.sesiones.map((s) => s.id),
        vivido.sesiones.map((s) => s.id),
        reason:
            'la versión nueva renombró las sesiones: los registros del '
            'nadador se quedaron sin a qué apuntar',
      );
    });

    test('y sus sesiones están guardadas, no solo en memoria', () async {
      final vivido = await unMesocicloVividoAMedias();
      final nueva = await planes.crearVersionDesde(vivido.id!);

      expect(await sesiones.obtenerDePlan(nueva.id!), hasLength(3));
    });

    test('**el nadador sigue viendo sus dos sesiones hechas**', () async {
      // Esta es la prueba de M34, y está escrita sobre lo que el nadador ve:
      // los registros son **alcanzables** desde la versión nueva. No se tocan,
      // no se copian y no se renombran — se leen siguiendo el linaje.
      final vivido = await unMesocicloVividoAMedias();
      final nueva = await planes.crearVersionDesde(vivido.id!);
      final guardada = (await planes.obtener(nueva.id!))!;

      final progreso = ProgresoEnElMacrociclo(
        mesociclos: [guardada],
        registros: await registrosDelLinaje(
          mesociclo: guardada,
          nadadorId: 'n-ana',
          registros: registros,
          planes: planes,
        ),
        hoy: hoy,
      );

      expect(
        progreso.hechas,
        hasLength(2),
        reason: 'el reajuste le dejó el historial en blanco',
      );
      expect(progreso.adherencia.descripcion, '2 de 3');
    });

    test('lo que el nadador escribió no se altera ni se duplica', () async {
      // FR-035 dice «no alterar ni perder». Copiar los registros al plan nuevo
      // los haría alcanzables y **también** los duplicaría: dos respuestas de
      // la misma sesión, y el entrenador leyendo adherencia sobre el doble.
      final vivido = await unMesocicloVividoAMedias();
      final antes = registros.todos;

      await planes.crearVersionDesde(vivido.id!);

      expect(registros.cuantosHay, antes.length);
      for (final registro in registros.todos) {
        final original = antes.firstWhere((r) => r.id == registro.id);
        expect(registro.realizada, original.realizada);
        expect(registro.rpePercibido, original.rpePercibido);
        expect(registro.observaciones, original.observaciones);
        expect(registro.planId, original.planId);
      }
    });

    test('y la versión anterior sigue entera y trazable', () async {
      // FR-030: la anterior se puede seguir leyendo. Es lo que hace que los
      // registros sigan teniendo dónde vivir.
      final vivido = await unMesocicloVividoAMedias();
      final nueva = await planes.crearVersionDesde(vivido.id!);

      final anterior = await planes.obtener(vivido.id!);
      expect(anterior, isNotNull);
      expect(anterior!.estado, EstadoPlan.aprobado);
      expect(anterior.sesiones, hasLength(3));
      expect(nueva.versionAnteriorId, vivido.id);
    });
  });

  group('el linaje se recorre sin perderse', () {
    test('tres versiones: lo anotado en la primera sigue contando', () async {
      final primera = await unMesocicloVividoAMedias();

      final segunda = await planes.crearVersionDesde(primera.id!);
      await planes.guardarAprobado(
        (await planes.obtener(
          segunda.id!,
        ))!.copiarCon(estado: EstadoPlan.aprobado),
        const {},
      );
      final tercera = await planes.crearVersionDesde(segunda.id!);
      final guardada = (await planes.obtener(tercera.id!))!;

      final delLinaje = await registrosDelLinaje(
        mesociclo: guardada,
        nadadorId: 'n-ana',
        registros: registros,
        planes: planes,
      );

      expect(delLinaje, hasLength(2));
    });

    test('lo respondido en la versión nueva manda sobre lo anterior', () async {
      // Si el nadador vuelve a responder la misma sesión en la versión nueva,
      // eso es lo que vale: su última palabra.
      final primera = await unMesocicloVividoAMedias();
      final segunda = await planes.crearVersionDesde(primera.id!);
      final guardada = (await planes.obtener(segunda.id!))!;

      final cambiada = guardada.sesiones.first;
      await registros.guardar(
        RegistroDeSesion(
          nadadorId: 'n-ana',
          planId: segunda.id!,
          sesionId: cambiada.id!,
          versionDePlan: '3.6.0',
          realizada: false,
          registradoEn: hoy,
          observaciones: 'Al final no pude ir.',
        ),
      );

      final delLinaje = await registrosDelLinaje(
        mesociclo: guardada,
        nadadorId: 'n-ana',
        registros: registros,
        planes: planes,
      );

      final deEsaSesion = delLinaje.where((r) => r.sesionId == cambiada.id);
      expect(deEsaSesion, hasLength(1));
      expect(deEsaSesion.single.realizada, isFalse);
      expect(deEsaSesion.single.observaciones, 'Al final no pude ir.');
    });

    test('un linaje que se muerde la cola no cuelga la app', () async {
      // Un `versionAnteriorId` que apunte a sí mismo es un dato corrupto, no
      // un caso de uso. Lo que no puede hacer es dejar la pantalla del nadador
      // girando para siempre.
      final id = await planes.guardarBorrador(mesociclo());
      await planes.guardarAprobado(
        (await planes.obtener(
          id,
        ))!.copiarCon(estado: EstadoPlan.aprobado, versionAnteriorId: id),
        const {},
      );

      final enBucle = (await planes.obtener(id))!;

      expect(
        registrosDelLinaje(
          mesociclo: enBucle,
          nadadorId: 'n-ana',
          registros: registros,
          planes: planes,
        ),
        completes,
      );
    });

    test('un mesociclo sin versión anterior lee solo lo suyo', () async {
      final vivido = await unMesocicloVividoAMedias();

      expect(
        await registrosDelLinaje(
          mesociclo: vivido,
          nadadorId: 'n-ana',
          registros: registros,
          planes: planes,
        ),
        hasLength(2),
      );
    });
  });
}

class _RegistrosEnMemoria implements RepositorioRegistros {
  final Map<String, RegistroDeSesion> _guardados = {};

  int get cuantosHay => _guardados.length;
  List<RegistroDeSesion> get todos => _guardados.values.toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      _guardados[registro.id] = registro;

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async => _guardados.values
      .where((r) => r.nadadorId == nadadorId && r.planId == planId)
      .toList();

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => _guardados.clear();

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();
}
