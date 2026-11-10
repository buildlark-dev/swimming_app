/// Guardar un plan guarda sus sesiones. Las dos implementaciones, lo mismo.
///
/// **Esto es un defecto de la feature 008 encontrado al construir la 009**, y
/// la razón por la que sobrevivió es el asunto de esta prueba.
///
/// `RepositorioPlanesFirestore.guardarBorrador` persistía solo
/// `planAJson(plan)`, que no incluye `sesiones`: en Firestore las sesiones son
/// documentos de una subcolección y las escribía **únicamente el editor**, una
/// a una, cuando el entrenador abría cada sesión a mano. Así que un plan
/// generado por el motor y guardado por código llegaba a Firestore **sin una
/// sola sesión**. El caso más claro era la cola de la feature 008: un plan
/// aprobado desde la petición de un nadador quedaba con sus microciclos y sin
/// nada dentro.
///
/// Y no fallaba nada. `RepositorioPlanesMemoria` guarda el objeto `Plan`
/// entero en un mapa, así que todas las pruebas Dart pasaban: el doble era
/// **más cómodo que el colaborador real**. Es la misma lección que la feature
/// 008 se llevó tres veces y que la 009 escribió en su quickstart.
///
/// Por eso esta prueba corre **la misma batería sobre las dos
/// implementaciones**: la de memoria y un doble con la forma de Firestore —el
/// documento del plan por un lado, las sesiones por otro, y `obtener`
/// juntándolos—. Lo que se fija es el contrato de la interfaz, no el de una
/// de las dos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Un repositorio de planes con la **forma de almacenamiento de Firestore**:
/// el plan en un documento, las sesiones en otra colección, y una lectura que
/// las junta.
///
/// No es un doble de conveniencia: es el colaborador real reducido a lo que
/// importa aquí. Si `guardarBorrador` no escribe las sesiones, este doble las
/// pierde — exactamente como las perdía Firestore.
class _PlanesConSesionesAparte implements RepositorioPlanes {
  _PlanesConSesionesAparte(this._sesiones);

  final RepositorioSesiones _sesiones;

  /// El documento del plan, **sin sus sesiones**, como lo guarda `planAJson`.
  final Map<String, Plan> _documentos = {};
  int _siguienteId = 1;

  @override
  Future<Plan?> obtener(String id) async {
    final documento = _documentos[id];
    if (documento == null) return null;
    // Como `RepositorioPlanesFirestore.obtener`: lee el plan y le pega las
    // sesiones de su subcolección.
    return documento.copiarCon(sesiones: await _sesiones.obtenerDePlan(id));
  }

  @override
  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado}) async =>
      _documentos.values
          .where((p) => estado == null || p.estado == estado)
          .toList();

  @override
  Future<String> guardarBorrador(Plan plan) async {
    final id = plan.id ?? 'p-${_siguienteId++}';
    _documentos[id] = plan.copiarCon(id: id, sesiones: const []);
    await _escribirLasSesiones(id, plan.sesiones);
    return id;
  }

  @override
  Future<void> guardarAprobado(Plan plan, Map<String, dynamic> a) async {
    final id = plan.id;
    if (id == null) throw const FalloDeDatos('sin identificador');
    // **Sin tocar las sesiones**, igual que Firestore: la regla de la
    // subcolección solo deja escribirlas mientras el plan no es inmutable, y
    // a estas alturas ya está firmado. El doble tiene que ser igual de
    // estricto que la regla, o esconde justo lo que la regla impide.
    _documentos[id] = plan.copiarCon(sesiones: const []);
  }

  /// Lo que la implementación real tiene que hacer y no hacía.
  ///
  /// Vive aquí para que el doble **no sea más fácil de contentar** que
  /// Firestore: si el día que se arregla la implementación real se escribe de
  /// otra forma, esta prueba lo nota.
  Future<void> _escribirLasSesiones(String planId, List<Sesion> sesiones) async {
    for (final sesion in sesiones) {
      await _sesiones.guardar(planId, sesion);
    }
  }

  @override
  Future<void> publicar(String id) async {}

  @override
  Future<Plan> crearVersionDesde(String id) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> exportar(String id) async => {};
}

void main() {
  Sesion sesion({String? id}) => Sesion(
    id: id,
    microcicloId: 'mc-1',
    fecha: DateTime(2026, 11, 18),
    objetivoTecnico: 'Economía de nado',
    partes: [
      Parte(
        tipo: TipoParte.central,
        series: [
          Serie(
            repeticiones: 8,
            distancia: 100,
            estilo: Estilo.libre,
            zona: Zona.a2,

            textoOriginal: '8x100 Libre A2 r:20',
          ),
        ],
      ),
    ],
  );

  Plan generado({List<Sesion>? sesiones}) => Plan(
    nombre: 'Microciclo: Base aeróbica y técnica',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    origen: OrigenPlan.automatico,
    versionMetodologia: '3.6.0',
    microciclos: const [
      Microciclo(
        id: 'mc-1',
        nombre: 'Base aeróbica y técnica',
        orden: 1,
        objetivo: 'Técnica y base',
      ),
    ],
    // Las sesiones que salen del motor **no traen identificador**: lo asigna el
    // almacenamiento. Es justo lo que hace que este defecto duela, porque los
    // registros del nadador se indexan por `sesionId`.
    sesiones: sesiones ?? [sesion(), sesion(), sesion()],
  );

  /// La misma batería sobre las dos implementaciones.
  void contrato(
    String cual,
    (RepositorioPlanes, RepositorioSesiones) Function() construir,
  ) {
    group('$cual — guardar un plan guarda sus sesiones', () {
      late RepositorioPlanes planes;
      late RepositorioSesiones sesiones;

      setUp(() {
        final (p, s) = construir();
        planes = p;
        sesiones = s;
      });

      test('un borrador guardado vuelve con sus sesiones', () async {
        final id = await planes.guardarBorrador(generado());

        final recuperado = await planes.obtener(id);
        expect(
          recuperado!.sesiones,
          hasLength(3),
          reason: 'el plan se guardó sin sus sesiones',
        );
        expect(recuperado.metros, greaterThan(0));
      });

      test('y están en la subcolección de sesiones, no solo en el plan',
          () async {
        // Es lo que distingue «guardado» de «guardado a medias»: el editor y
        // la pantalla del nadador leen de ahí.
        final id = await planes.guardarBorrador(generado());

        expect(await sesiones.obtenerDePlan(id), hasLength(3));
      });

      test('cada sesión guardada tiene identificador', () async {
        // **Esta es la mitad que convierte el defecto en pérdida de datos.**
        // Los `RegistroDeSesion` del nadador apuntan a `sesionId`. Una sesión
        // guardada sin identificador no tiene a qué apuntar.
        final id = await planes.guardarBorrador(generado());

        for (final sesion in (await planes.obtener(id))!.sesiones) {
          expect(sesion.id, isNotNull);
          expect(sesion.id, isNotEmpty);
        }
      });

      test('un plan aprobado CONSERVA sus sesiones', () async {
        // El camino de la cola de la feature 008: genera, guarda el borrador y
        // firma. Si al firmar se perdieran, lo que queda firmado está vacío.
        //
        // **Conserva, no vuelve a escribir**, y la diferencia costó un fallo
        // en el recorrido. La primera versión de esta prueba decía «también
        // guarda sus sesiones» y la implementación la obedeció: `guardarAprobado`
        // las reescribía. Pero el documento del plan ya se había escrito con
        // `estado: aprobado`, y la regla de la subcolección solo deja escribir
        // sesiones mientras el plan **no** es inmutable (FR-025). Así que
        // firmar fallaba con «The caller does not have permission» y los
        // mesociclos se quedaban en borrador.
        //
        // Las sesiones se escriben cuando el plan es borrador. Firmar las
        // congela: eso es lo que significa firmar.
        final id = await planes.guardarBorrador(generado());
        final borrador = (await planes.obtener(id))!;

        await planes.guardarAprobado(
          borrador.copiarCon(estado: EstadoPlan.aprobado),
          const {},
        );

        final firmado = await planes.obtener(id);
        expect(firmado!.sesiones, hasLength(3));
        expect(firmado.estado, EstadoPlan.aprobado);
      });

      test('y firmar no vuelve a escribirlas', () async {
        // Lo que la regla de Firestore exige, dicho sobre la interfaz: al
        // firmar, el almacén de sesiones no recibe ninguna escritura más.
        final id = await planes.guardarBorrador(generado());
        final borrador = (await planes.obtener(id))!;
        final antes = (await sesiones.obtenerDePlan(id))
            .map((s) => s.id)
            .toList();

        await planes.guardarAprobado(
          borrador.copiarCon(estado: EstadoPlan.aprobado),
          const {},
        );

        expect(
          (await sesiones.obtenerDePlan(id)).map((s) => s.id).toList(),
          antes,
          reason: 'firmar tocó las sesiones, y lo firmado es inmutable',
        );
      });

      test('guardar dos veces no duplica las sesiones', () async {
        // Sin esto, el arreglo se pasa de largo: un `add` por sesión en cada
        // guardado deja seis sesiones donde había tres, y el nadador ve la
        // semana repetida.
        final id = await planes.guardarBorrador(generado());
        final conIds = (await planes.obtener(id))!;

        await planes.guardarBorrador(conIds);

        expect(
          (await planes.obtener(id))!.sesiones,
          hasLength(3),
          reason: 'guardar otra vez duplicó las sesiones',
        );
      });

      test('un plan sin sesiones se guarda sin inventarlas', () async {
        final id = await planes.guardarBorrador(
          generado(sesiones: const []),
        );

        expect((await planes.obtener(id))!.sesiones, isEmpty);
      });
    });
  }

  contrato('en memoria', () {
    final sesiones = RepositorioSesionesMemoria();
    return (RepositorioPlanesMemoria(sesiones: sesiones), sesiones);
  });

  contrato('con las sesiones aparte, como Firestore', () {
    final sesiones = RepositorioSesionesMemoria();
    return (_PlanesConSesionesAparte(sesiones), sesiones);
  });
}
