/// Las invariantes del macrociclo, del nivel que la feature 009 añade.
///
/// **Escrito antes de `lib/dominio/macrociclo/macrociclo.dart`** (principio III:
/// el cerrojo va antes de lo que vigila). Cada invariante de aquí tiene su
/// control negativo en T006, anotado al final de este archivo: quitar la
/// guarda, ver la prueba roja, devolverla. Una invariante que nunca se vio en
/// rojo es un adorno.
///
/// Las invariantes no son cosmética. Dos de ellas evitan un estado que no
/// fallaría por su cuenta:
///
/// - **Un macrociclo sin mesociclos** sería un nombre con nada dentro, y la
///   pantalla del nadador lo pintaría vacío sin que nada se queje.
/// - **`impedimentosParaAprobar` cuenta como impedimento un mesociclo que no
///   está en la lista.** Comprobar solo que los presentes están aprobados
///   pasaría en vacío con una lista incompleta, que es exactamente la forma de
///   fallo que esta feature persigue.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

DateTime d(int dia) => DateTime(2026, 11, dia);

BloqueConfirmado bloque({
  FaseAtr? fase = FaseAtr.acumulacion,
  required DateTime desde,
  required DateTime hasta,
  String porQue = 'Acumulación, las primeras 4 semanas del macrociclo.',
}) => BloqueConfirmado(
  fase: fase,
  desde: desde,
  hasta: hasta,
  porQue: porQue,
);

EstructuraConfirmada estructura({List<BloqueConfirmado>? bloques}) =>
    EstructuraConfirmada(
      modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
      modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
      bloques:
          bloques ??
          [
            bloque(desde: d(1), hasta: d(10)),
            bloque(
              fase: FaseAtr.realizacion,
              desde: d(11),
              hasta: d(20),
              porQue: 'Realización, las últimas 2 semanas antes de la '
                  'competencia.',
            ),
          ],
      confirmadaEn: d(1),
    );

Macrociclo macrociclo({
  List<String>? mesociclos,
  String nadadorId = 'nadador-1',
  String nombre = 'Hacia el Departamental',
  String versionMetodologia = '3.6.0',
  EstadoPlan estado = EstadoPlan.borrador,
}) => Macrociclo(
  nadadorId: nadadorId,
  nombre: nombre,
  estructura: estructura(),
  mesociclos: mesociclos ?? ['plan-a', 'plan-b'],
  fechaDeCompetencia: d(20),
  versionMetodologia: versionMetodologia,
  estado: estado,
);

Plan mesociclo({required String id, required EstadoPlan estado}) => Plan(
  id: id,
  nombre: 'Técnica de eficiencia',
  categoria: Categoria.competitivo,
  estiloObjetivo: Estilo.libre,
  estado: estado,
  macrocicloId: 'macro-1',
  ordenEnElMacrociclo: 0,
);

void main() {
  group('Macrociclo', () {
    test('sin mesociclos no se puede construir', () {
      // «Un macrociclo con cero mesociclos no es construible: sería un nombre
      // con nada dentro» (data-model.md).
      expect(
        () => macrociclo(mesociclos: const []),
        throwsA(isA<MacrocicloInvalido>()),
      );
    });

    test('con un mesociclo repetido no se puede construir', () {
      expect(
        () => macrociclo(mesociclos: const ['plan-a', 'plan-a']),
        throwsA(isA<MacrocicloInvalido>()),
      );
    });

    test('el orden de los mesociclos es el de la preparación y se conserva', () {
      // «Su orden es el de la preparación, no un accidente del
      // almacenamiento»: ni se ordena alfabéticamente ni se normaliza.
      final m = macrociclo(mesociclos: const ['plan-z', 'plan-a', 'plan-m']);
      expect(m.mesociclos, ['plan-z', 'plan-a', 'plan-m']);
    });

    test('la lista de mesociclos no se puede modificar por fuera', () {
      // Sin esto, quien reciba el macrociclo podría reordenar la preparación
      // sin pasar por ninguna invariante.
      final m = macrociclo();
      expect(() => m.mesociclos.add('plan-c'), throwsUnsupportedError);
    });

    test('nace sin identificador, como el plan', () {
      // «Nulo hasta que se guarda, como en `Plan`».
      expect(macrociclo().id, isNull);
    });

    test('sin nadador no se puede construir', () {
      // «Obligatorio, no vacío. Un macrociclo es de un nadador.»
      expect(
        () => macrociclo(nadadorId: '   '),
        throwsA(isA<MacrocicloInvalido>()),
      );
    });

    test('sin nombre no se puede construir', () {
      expect(() => macrociclo(nombre: ''), throwsA(isA<MacrocicloInvalido>()));
    });

    test('sin versión de metodología no se puede construir', () {
      // FR-013: cada nivel registra bajo qué metodología se construyó. Un
      // macrociclo sin sello sería un nivel que no la registra.
      expect(
        () => macrociclo(versionMetodologia: ''),
        throwsA(isA<MacrocicloInvalido>()),
      );
    });
  });

  group('EstructuraConfirmada', () {
    test('sin modelo de la prueba no se puede construir', () {
      // Lo que el entrenador aporta y ninguna fórmula deriva (FR-007).
      expect(
        () => EstructuraConfirmada(
          modeloDeLaPrueba: '   ',
          modeloDelNadador: 'Crol dominante.',
          bloques: [bloque(desde: d(1), hasta: d(10))],
          confirmadaEn: d(1),
        ),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('sin modelo del nadador no se puede construir', () {
      expect(
        () => EstructuraConfirmada(
          modeloDeLaPrueba: '200 libre.',
          modeloDelNadador: '',
          bloques: [bloque(desde: d(1), hasta: d(10))],
          confirmadaEn: d(1),
        ),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('los dos modelos se guardan sin espacios de sobra', () {
      final e = EstructuraConfirmada(
        modeloDeLaPrueba: '  200 libre.  ',
        modeloDelNadador: '  Crol dominante.  ',
        bloques: [bloque(desde: d(1), hasta: d(10))],
        confirmadaEn: d(1),
      );
      expect(e.modeloDeLaPrueba, '200 libre.');
      expect(e.modeloDelNadador, 'Crol dominante.');
    });

    test('sin bloques no se puede construir', () {
      expect(
        () => estructura(bloques: const []),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('dos bloques que se solapan no se pueden construir', () {
      expect(
        () => estructura(
          bloques: [
            bloque(desde: d(1), hasta: d(10)),
            bloque(desde: d(8), hasta: d(20)),
          ],
        ),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('dos bloques con un hueco entre ellos no se pueden construir', () {
      // Un hueco sería una semana de la preparación sin fase y sin sesiones,
      // y el nadador la vería en blanco sin que nada avisara.
      expect(
        () => estructura(
          bloques: [
            bloque(desde: d(1), hasta: d(10)),
            bloque(desde: d(13), hasta: d(20)),
          ],
        ),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('los bloques fuera de orden no se reordenan: se rechazan', () {
      // Ordenarlos en silencio esconderia el error de quien los pasó.
      expect(
        () => estructura(
          bloques: [
            bloque(desde: d(11), hasta: d(20)),
            bloque(desde: d(1), hasta: d(10)),
          ],
        ),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('dos bloques contiguos sí se pueden construir', () {
      // El control de que las dos pruebas de arriba no pasan por rechazarlo
      // todo. Un bloque va de `desde` a `hasta` incluidos, así que contiguo
      // significa que el siguiente empieza **al día siguiente**.
      expect(
        () => estructura(
          bloques: [
            bloque(desde: d(1), hasta: d(10)),
            bloque(desde: d(11), hasta: d(20)),
          ],
        ),
        returnsNormally,
      );
    });

    test('la hora del día no convierte dos contiguos en un solape', () {
      // Un bloque que acaba el día 10 **por la tarde** y el siguiente que
      // empieza el 11 **por la mañana** son contiguos: son dos días seguidos.
      // Sin comparar por fecha entera, entre las dos marcas hay 8 horas, o sea
      // `inDays == 0`, y la estructura se rechazaría por «solape» según la
      // hora a la que alguien abrió la app. La misma trampa que `_diasEnteros`
      // evita en la feature 008.
      //
      // **La primera versión de esta prueba no vigilaba nada**: usaba las
      // 00:00 del día 10 y las 23:59 del 11, que dan `inDays == 1` con
      // comparación por fecha entera y sin ella. Pasaba de las dos maneras, y
      // el control negativo de T006 lo destapó. Las horas de aquí están
      // elegidas para que la diferencia importe.
      expect(
        () => estructura(
          bloques: [
            bloque(
              desde: DateTime(2026, 11, 1, 7),
              hasta: DateTime(2026, 11, 10, 19),
            ),
            bloque(
              desde: DateTime(2026, 11, 11, 7),
              hasta: DateTime(2026, 11, 20, 19),
            ),
          ],
        ),
        returnsNormally,
      );
    });
  });

  group('BloqueConfirmado', () {
    test('un bloque que no avanza en el tiempo no se puede construir', () {
      expect(
        () => bloque(desde: d(10), hasta: d(1)),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('un bloque de un solo instante no se puede construir', () {
      expect(
        () => bloque(desde: d(10), hasta: d(10)),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('un bloque que empieza y acaba el mismo día tampoco, aunque cambie '
        'la hora', () {
      // De la mañana a la tarde del mismo día **no es un bloque**: es un día.
      // Sin comparar por fecha entera, `hasta.isAfter(desde)` sería cierto y
      // se aceptaría. La prueba de arriba no lo habría visto, porque usa las
      // dos marcas idénticas.
      expect(
        () => bloque(
          desde: DateTime(2026, 11, 10, 7),
          hasta: DateTime(2026, 11, 10, 19),
        ),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('un bloque sin razón escrita no se puede construir', () {
      // M2: un bloque cuya razón no se puede leer es metodología decidida en
      // silencio. Por eso `porQue` no es opcional ni puede venir vacío.
      expect(
        () => bloque(desde: d(1), hasta: d(10), porQue: '  '),
        throwsA(isA<EstructuraInvalida>()),
      );
    });

    test('un bloque sin fase es válido: hay categorías que no usan ATR', () {
      // M6. Aquí `null` no es un hueco por rellenar: es la respuesta correcta,
      // porque el motor prohíbe la fase en esas categorías.
      final sinFase = bloque(fase: null, desde: d(1), hasta: d(10));
      expect(sinFase.fase, isNull);
    });
  });

  group('impedimentosParaAprobar (M14)', () {
    final m = macrociclo(mesociclos: const ['plan-a', 'plan-b']);

    test('con todos los mesociclos aprobados no hay impedimentos', () {
      expect(
        impedimentosParaAprobar(
          macrociclo: m,
          mesociclos: [
            mesociclo(id: 'plan-a', estado: EstadoPlan.aprobado),
            mesociclo(id: 'plan-b', estado: EstadoPlan.aprobado),
          ],
        ),
        isEmpty,
      );
    });

    test('un mesociclo en borrador impide firmar el macrociclo', () {
      // «Un macrociclo no se puede firmar mientras una parte suya no lo
      // está.»
      final impedimentos = impedimentosParaAprobar(
        macrociclo: m,
        mesociclos: [
          mesociclo(id: 'plan-a', estado: EstadoPlan.aprobado),
          mesociclo(id: 'plan-b', estado: EstadoPlan.borrador),
        ],
      );
      expect(impedimentos, hasLength(1));
      expect(impedimentos.single.toString(), contains('plan-b'));
    });

    test('un mesociclo que no está en la lista también impide firmar', () {
      // **Esta es la que pasaría en vacío.** Comprobar solo que los presentes
      // están aprobados daría verde con una lista incompleta, y el macrociclo
      // quedaría firmado señalando a un mesociclo que nadie miró.
      final impedimentos = impedimentosParaAprobar(
        macrociclo: m,
        mesociclos: [mesociclo(id: 'plan-a', estado: EstadoPlan.aprobado)],
      );
      expect(impedimentos, hasLength(1));
      expect(impedimentos.single.toString(), contains('plan-b'));
    });

    test('una lista vacía impide firmar por cada mesociclo que falta', () {
      expect(
        impedimentosParaAprobar(macrociclo: m, mesociclos: const []),
        hasLength(2),
      );
    });
  });
}

// --- Control negativo (T006) --------------------------------------------
//
// Cada guarda de `macrociclo.dart` se quitó una a una y se comprobó que la
// prueba correspondiente se pone roja, antes de devolverla:
//
// | Guarda quitada                                  | Prueba que se puso roja |
// |-------------------------------------------------|-------------------------|
// | `mesociclos.isEmpty`                            | «sin mesociclos no se puede construir» |
// | ids repetidos                                   | «con un mesociclo repetido…» |
// | `List.unmodifiable` en `mesociclos`             | «la lista … no se puede modificar por fuera» |
// | `nadadorId` vacío tras recortar                 | «sin nadador no se puede construir» |
// | `nombre` vacío                                  | «sin nombre no se puede construir» |
// | `versionMetodologia` vacía                      | «sin versión de metodología…» |
// | modelos vacíos tras recortar                    | «sin modelo de la prueba…», «sin modelo del nadador…» |
// | `bloques.isEmpty`                               | «sin bloques no se puede construir» |
// | solape entre bloques                            | «dos bloques que se solapan…» |
// | hueco entre bloques                             | «dos bloques con un hueco…» |
// | orden de los bloques                            | «los bloques fuera de orden…» |
// | comparación por fecha entera (`_soloLaFecha` devolviendo el instante) | «la hora del día no convierte dos contiguos en un solape», «un bloque que empieza y acaba el mismo día…» |
// | `hasta` posterior a `desde`                     | «un bloque que no avanza en el tiempo…», «un bloque de un solo instante…» |
// | `porQue` vacío                                  | «un bloque sin razón escrita…» |
// | mesociclo ausente de la lista en `impedimentos` | «un mesociclo que no está en la lista…» |
//
// **Y una de las dieciséis se quedó verde**, que es exactamente para lo que
// sirve esto. La primera versión de «la hora del día» usaba las 00:00 del día
// 10 y las 23:59 del 11: con comparación por fecha entera o sin ella, la
// diferencia salía `inDays == 1`, así que la prueba pasaba de las dos maneras y
// no vigilaba la guarda que decía vigilar. Con las horas cambiadas —tarde del
// 10, mañana del 11— y con la prueba del bloque de un solo día, las dos se
// ponen rojas al quitar la guarda.
//
// Es la lección de la feature 008 otra vez, y es la razón por la que el
// principio III pide el control negativo y no solo la prueba: **una prueba
// verde no dice nada hasta que se la ha visto roja por el motivo correcto.**
