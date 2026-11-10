/// Una versión nueva de un mesociclo **conserva lo que lo sitúa**.
///
/// **Encontrado reajustando en el Pixel 7.** El entrenador reajustó el bloque
/// 1 y la pantalla de revisión pasó a decir, en ese bloque y solo en ese,
/// «Metodología sin sellar». Los otros dos seguían con 3.6.0.
///
/// `crearVersionDesde` construye el `Plan` nuevo campo a campo, y se dejaba
/// tres:
///
/// - `versionMetodologia`. Es un requisito central de la feature —cada nivel
///   registra bajo qué versión se construyó— y el reajuste lo borraba.
/// - `macrocicloId`. La versión nueva dejaba de saber de qué macrociclo es.
/// - `ordenEnElMacrociclo`. Sin él, `progreso_en_el_macrociclo` cae a
///   `?? 0` y al nadador se le dice que va por el **bloque 1** aunque esté en
///   el dos. Un número equivocado dicho con toda confianza.
///
/// **Ninguna prueba lo veía porque las dos implementaciones se dejaban los
/// mismos tres.** El doble en memoria no era más amable que Firestore esta
/// vez: era igual de olvidadizo, así que compararlos no decía nada. De ahí
/// que esto no compare una contra otra, sino las dos contra lo que el plan
/// traía.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  group('en memoria', () {
    late RepositorioPlanesMemoria planes;

    setUp(() {
      planes = RepositorioPlanesMemoria(sesiones: RepositorioSesionesMemoria());
    });

    /// Un mesociclo entregado, como los que deja la derivación.
    Future<String> mesocicloEntregado() async {
      final id = await planes.guardarBorrador(
        Plan(
          nombre: 'Mesociclo 2: Transformación',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
          origen: OrigenPlan.automatico,
          versionMetodologia: '3.6.0',
          macrocicloId: 'macro-1',
          ordenEnElMacrociclo: 1,
        ),
      );

      final borrador = (await planes.obtener(id))!;
      await planes.guardarAprobado(
        borrador.copiarCon(estado: EstadoPlan.aprobado),
        const {},
      );
      return id;
    }

    test('conserva el sello de metodología', () async {
      final id = await mesocicloEntregado();

      final nueva = await planes.crearVersionDesde(id);

      expect(
        nueva.versionMetodologia,
        '3.6.0',
        reason: 'reajustar borraba bajo qué metodología se construyó',
      );
    });

    test('sigue sabiendo de qué macrociclo es', () async {
      final id = await mesocicloEntregado();

      final nueva = await planes.crearVersionDesde(id);

      expect(nueva.macrocicloId, 'macro-1');
    });

    test('y en qué posición va, que es lo que el nadador lee', () async {
      // `progreso_en_el_macrociclo` hace `(ordenEnElMacrociclo ?? 0) + 1`.
      // Perderlo no deja un hueco: dice «bloque 1» con toda confianza.
      final id = await mesocicloEntregado();

      final nueva = await planes.crearVersionDesde(id);

      expect(
        nueva.ordenEnElMacrociclo,
        1,
        reason: 'sin esto al nadador se le dice que va por el bloque 1',
      );
    });

    test('y lo que ya conservaba sigue conservándolo', () async {
      // Que se añadan tres campos no puede costar los que ya estaban.
      final id = await mesocicloEntregado();

      final nueva = await planes.crearVersionDesde(id);

      expect(nueva.nombre, 'Mesociclo 2: Transformación');
      expect(nueva.origen, OrigenPlan.automatico);
      expect(nueva.versionAnteriorId, id);
      expect(nueva.estado, EstadoPlan.borrador);
    });
  });

  group('en Firestore, leído en su fuente', () {
    // `cloud_firestore` necesita una app Flutter, así que aquí se fija la
    // propiedad sobre el código. Es el mismo recurso que la feature 008 usó
    // para el contrato con el servidor.
    const ruta = 'lib/datos/firestore/repositorios_firestore.dart';

    late String cuerpo;

    setUpAll(() {
      final fuente = File(ruta).readAsStringSync();
      const firma = 'Future<Plan> crearVersionDesde(String idAprobado) async {';
      final desde = fuente.indexOf(firma);
      expect(desde, greaterThan(-1), reason: 'no se encontró «$firma»');

      // Hasta el cierre del `Plan(` que construye la versión nueva.
      final abre = fuente.indexOf('final nueva = Plan(', desde);
      final cierra = fuente.indexOf(');', abre);
      expect(abre, greaterThan(-1));
      cuerpo = fuente.substring(abre, cierra);
    });

    test('la prueba no pasa por vacía', () {
      expect(cuerpo.length, greaterThan(100));
      expect(cuerpo, contains('versionAnteriorId:'));
    });

    test('copia el sello de metodología', () {
      expect(
        cuerpo,
        contains('versionMetodologia: aprobado.versionMetodologia'),
      );
    });

    test('copia el macrociclo al que pertenece', () {
      expect(cuerpo, contains('macrocicloId: aprobado.macrocicloId'));
    });

    test('copia su posición en el macrociclo', () {
      expect(
        cuerpo,
        contains('ordenEnElMacrociclo: aprobado.ordenEnElMacrociclo'),
      );
    });
  });
}
