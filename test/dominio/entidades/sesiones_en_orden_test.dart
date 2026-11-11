/// Las sesiones de un microciclo salen **en el orden en que ocurren**.
///
/// **Encontrado recorriendo el quickstart en el Pixel 7.** Ana abría «Ver
/// Plan» con su macrociclo entregado y su camino salía así:
///
///     Miércoles 11/11
///     Viernes 13/11
///     Lunes 9/11
///
/// Cada semana igual, y las ocho del macrociclo igual. Un camino que no se lee
/// como un camino.
///
/// La causa está en Firestore y en que nadie la deshacía:
/// `RepositorioSesionesFirestore.obtenerDePlan` lee la subcolección sin
/// `orderBy`, así que los documentos vuelven en el orden del identificador,
/// que para identificadores automáticos es tan bueno como aleatorio. Y
/// `sesionesDe` filtraba por microciclo sin ordenar, así que la pantalla
/// pintaba lo que le llegara.
///
/// Ninguna prueba lo vio porque **el doble en memoria conserva el orden de
/// inserción**: las pruebas siembran las sesiones en orden y las reciben en
/// orden. Otra vez el doble siendo más amable que el colaborador real.
///
/// Se arregla en el dominio y no en la pantalla a propósito. «Las sesiones de
/// esta semana, en el orden en que ocurren» es una propiedad del plan, no de
/// quien lo dibuja: el entrenador que lo revisa y el nadador que lo recorre
/// tienen que ver lo mismo, y si viviera en una de las dos pantallas la otra
/// seguiría desordenada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  Sesion sesion(String id, DateTime? fecha, {String microciclo = 'mc-1'}) =>
      Sesion(
        id: id,
        microcicloId: microciclo,
        fecha: fecha,
        objetivoTecnico: 'Economía de nado',
      );

  Plan planCon(List<Sesion> sesiones) => Plan(
    id: 'p-1',
    nombre: 'Base aeróbica',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    versionMetodologia: '3.6.0',
    microciclos: const [
      Microciclo(id: 'mc-1', nombre: 'Semana 1', orden: 1),
      Microciclo(id: 'mc-2', nombre: 'Semana 2', orden: 2),
    ],
    sesiones: sesiones,
  );

  test('vienen desordenadas y salen en orden', () {
    // El orden exacto que devolvió Firestore en el recorrido: miércoles,
    // viernes, lunes.
    final plan = planCon([
      sesion('mie', DateTime(2026, 11, 11)),
      sesion('vie', DateTime(2026, 11, 13)),
      sesion('lun', DateTime(2026, 11, 9)),
    ]);

    expect(plan.sesionesDe('mc-1').map((s) => s.id).toList(), [
      'lun',
      'mie',
      'vie',
    ], reason: 'el camino del nadador tiene que leerse como un camino');
  });

  test('sigue filtrando por microciclo', () {
    // Que ordene no puede costar lo que ya hacía.
    final plan = planCon([
      sesion('b', DateTime(2026, 11, 18), microciclo: 'mc-2'),
      sesion('a', DateTime(2026, 11, 9)),
    ]);

    expect(plan.sesionesDe('mc-1').map((s) => s.id).toList(), ['a']);
    expect(plan.sesionesDe('mc-2').map((s) => s.id).toList(), ['b']);
  });

  test('una sesión sin fecha va al final, no al principio', () {
    // **Sin fecha no es «antes de todo».** Una sesión sin día asignado existe
    // —`SinFecha` es un estado que la app sabe decir— y ponerla primera
    // encabezaría la semana con la única que el nadador no puede marcar.
    final plan = planCon([
      sesion('sin-dia', null),
      sesion('mie', DateTime(2026, 11, 11)),
      sesion('lun', DateTime(2026, 11, 9)),
    ]);

    expect(plan.sesionesDe('mc-1').map((s) => s.id).toList(), [
      'lun',
      'mie',
      'sin-dia',
    ]);
  });

  test('dos sin fecha conservan el orden que traían', () {
    // Un orden estable: sin fecha no hay nada que comparar, y reordenarlas
    // entre ellas sería inventarse un criterio.
    final plan = planCon([
      sesion('primera', null),
      sesion('segunda', null),
      sesion('con-dia', DateTime(2026, 11, 9)),
    ]);

    expect(plan.sesionesDe('mc-1').map((s) => s.id).toList(), [
      'con-dia',
      'primera',
      'segunda',
    ]);
  });

  test('dos el mismo día conservan el orden que traían', () {
    final plan = planCon([
      sesion('manana', DateTime(2026, 11, 9, 7)),
      sesion('tarde', DateTime(2026, 11, 9, 18)),
    ]);

    expect(plan.sesionesDe('mc-1').map((s) => s.id).toList(), [
      'manana',
      'tarde',
    ]);
  });

  test('ordenar no toca la lista del plan', () {
    // `sesiones` es lo que se guardó. Si `sesionesDe` ordenara en sitio,
    // leerlo cambiaría el objeto, y eso es un efecto que nadie espera de un
    // getter.
    final plan = planCon([
      sesion('mie', DateTime(2026, 11, 11)),
      sesion('lun', DateTime(2026, 11, 9)),
    ]);

    plan.sesionesDe('mc-1');

    expect(plan.sesiones.map((s) => s.id).toList(), ['mie', 'lun']);
  });
}
