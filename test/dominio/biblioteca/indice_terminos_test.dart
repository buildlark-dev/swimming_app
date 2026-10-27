import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/generacion/selector_ejercicios.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

import '../notacion/ayuda_pruebas.dart';

/// Pruebas del índice de términos de diagnóstico — tarea T070.
///
/// La tabla de `docs/metodologia/correspondencia_diagnostico.md` la confirmó el
/// entrenador fila por fila. Estas pruebas la fijan: si alguien toca el índice
/// y rompe una correspondencia que él aprobó, falla aquí.
void main() {
  late IndiceTerminos indice;
  late SelectorEjercicios selector;

  setUpAll(() {
    indice = IndiceTerminos.desdeJson(
      jsonDecode(
            File(
              'assets/biblioteca/terminos_diagnostico.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    selector = SelectorEjercicios(cargarBibliotecaReal(), indice: indice);
  });

  /// Nombres que el selector devuelve para un diagnóstico, en orden.
  List<String> elegidosPara(Estilo estilo, String frase) {
    final seleccion = selector.elegir(
      estilo: estilo,
      diagnostico: [frase],
      cuantos: 99,
    );
    return seleccion.ejercicios.map((e) => e.nombre).toList();
  }

  /// Verdadero si el diagnóstico se reportó como vacío de Biblioteca.
  ///
  /// Hay que mirar esto y no la lista de ejercicios: cuando un diagnóstico no
  /// encuentra nada, el selector reporta el vacío **y además** completa con la
  /// progresión de la sección 15, porque la sesión necesita trabajo técnico
  /// de todas formas. Lo que distingue «encontró» de «no encontró» es el
  /// vacío, no que la lista venga llena.
  bool reportaVacio(Estilo estilo, String frase) {
    final seleccion = selector.elegir(
      estilo: estilo,
      diagnostico: [frase],
      cuantos: 99,
    );
    return seleccion.vacios.isNotEmpty;
  }

  group('el índice no referencia nada que no exista', () {
    test('todos sus ejercicios están en la Biblioteca Oficial', () {
      final reales = cargarBibliotecaReal().todos.map((e) => e.nombre).toSet();
      final referenciados = indice.ejerciciosReferenciados;
      final inexistentes = referenciados.difference(reales);

      expect(
        inexistentes,
        isEmpty,
        reason:
            'El índice nombra ejercicios que no están en la sección 19. '
            'Eso es invención por la puerta de atrás (regla R2): '
            '${inexistentes.join(', ')}',
      );
    });

    test('el ejercicio de cada entrada pertenece al estilo de la entrada', () {
      final porNombre = {
        for (final e in cargarBibliotecaReal().todos) e.nombre: e,
      };

      for (final entrada in indice.entradas) {
        for (final nombre in entrada.ejercicios) {
          final ejercicio = porNombre[nombre];
          expect(ejercicio, isNotNull, reason: '«$nombre» no existe');
          expect(
            ejercicio!.estilo == entrada.estilo ||
                ejercicio.estilo == Estilo.general,
            isTrue,
            reason:
                'La entrada «${entrada.frase}» es de '
                '${entrada.estilo.nombre} pero «$nombre» es de '
                '${ejercicio.estilo.nombre}. El selector filtra por estilo, '
                'así que esa correspondencia nunca se aplicaría',
          );
        }
      }
    });

    test('ninguna entrada queda sin ejercicios', () {
      for (final entrada in indice.entradas) {
        expect(
          entrada.ejercicios,
          isNotEmpty,
          reason:
              'La entrada «${entrada.frase}» no lleva a ningún ejercicio. '
              'Una frase sin ejercicio se omite del índice: así se reporta '
              'como vacío de Biblioteca',
        );
      }
    });
  });

  group('las 40 frases del entrenador encuentran ejercicio', () {
    // Primer ejercicio esperado por frase, tal como él confirmó la tabla.
    const esperados = <(Estilo, String, String)>[
      (Estilo.libre, 'rolido insuficiente', 'ROLIDO (Libre)'),
      (Estilo.libre, 'poco rolido', 'ROLIDO (Libre)'),
      (Estilo.libre, 'no gira la cadera', '3+3 PATADA LATERAL'),
      (Estilo.libre, 'codo bajo', 'TOCAR AXILA'),
      (Estilo.libre, 'cabeza alta', 'PATADA MIRANDO EL FONDO'),
      (Estilo.libre, 'mirada al frente', 'PATADA MIRANDO EL FONDO'),
      (Estilo.libre, 'cadera abajo', 'PATADA MIRANDO EL FONDO'),
      (Estilo.libre, 'cadera caída', 'PATADA MIRANDO EL FONDO'),
      (Estilo.libre, 'piernas caídas', 'PATADA MIRANDO EL FONDO'),
      (Estilo.libre, 'brazada cruzada', 'PUNTO MUERTO'),
      (Estilo.libre, 'empujes cortos', 'PULGAR ROZA EL MUSLO'),
      (Estilo.libre, 'patada desde rodillas', 'PATADA CORTA – PIES CON ESPUMA'),
      (Estilo.libre, 'respira al frente', 'FLECHA (Libre)'),
      (Estilo.espalda, 'rolido insuficiente', 'ROLIDO (Espalda)'),
      (Estilo.espalda, 'cabeza alta', 'PATADA MIRANDO EL TECHO'),
      (Estilo.espalda, 'cabeza levantada', 'PATADA MIRANDO EL TECHO'),
      (
        Estilo.espalda,
        'patada desde las rodillas',
        'PATADA MI EXTENDIDOS – ANTI-BICICLETA',
      ),
      (Estilo.espalda, 'patada caída', 'PATADA MI EXTENDIDOS – ANTI-BICICLETA'),
      (Estilo.espalda, 'cadera caída', 'PATADA MIRANDO EL TECHO'),
      (Estilo.espalda, 'brazo flexionado en fase aérea', 'MANO AL CIELO'),
      (Estilo.pecho, 'dosiflexión', 'TOCANDO TALÓN/TOBILLO'),
      (Estilo.pecho, 'dorsiflexión', 'TOCANDO TALÓN/TOBILLO'),
      (Estilo.pecho, 'patada sin flexionar tobillos', 'TOCANDO TALÓN/TOBILLO'),
      (Estilo.pecho, 'patada con plantiflexión', 'TOCANDO TALÓN/TOBILLO'),
      (Estilo.pecho, 'saca los pies del agua', 'MI × RESPIRACIÓN (Pecho)'),
      (Estilo.pecho, 'mirada al frente', 'MI × RESPIRACIÓN (Pecho)'),
      (Estilo.pecho, 'cabeza arriba', 'MI × RESPIRACIÓN (Pecho)'),
      (Estilo.pecho, 'no coordina el estilo', 'BRAZA 1-2-3'),
      (Estilo.pecho, 'patada y brazada al mismo tiempo', 'BRAZA 1-2-3'),
      (
        Estilo.pecho,
        'baja las manos hasta la cadera',
        'BRAZADA CORTA – CODOS JUNTOS',
      ),
      (Estilo.pecho, 'no desliza', 'FLECHA (Pecho)'),
      (Estilo.pecho, 'sin timing', 'BRAZA 1-2-3'),
      (
        Estilo.mariposa,
        'patada desde las rodillas',
        'SACAR LA CADERA – ONDULACIÓN',
      ),
      (Estilo.mariposa, 'no mueve la cadera', 'SACAR LA CADERA – ONDULACIÓN'),
      (Estilo.mariposa, 'separa los pies', 'PN EN SOLDADO'),
      (Estilo.mariposa, 'brazos no salen del agua', 'DELFINEO COMPLETO'),
      (Estilo.mariposa, 'cabeza levantada siempre', 'PN EN SOLDADO'),
      (
        Estilo.mariposa,
        'no empuja hasta la cadera',
        'PULGAR ROZA EL MUSLO (Mariposa)',
      ),
      (
        Estilo.mariposa,
        'brazos flexionados en el recobro',
        'DELFINEO COMPLETO',
      ),
      (
        Estilo.mariposa,
        'no lleva las manos hasta adelante',
        'FLECHA (Mariposa)',
      ),
      (Estilo.mariposa, 'sin timing', 'DELFÍN 2 BATIDAS – ENTRADA/SALIDA'),
      (
        Estilo.mariposa,
        'muchas patadas por cada brazada',
        'DELFÍN 2 BATIDAS – ENTRADA/SALIDA',
      ),
    ];

    for (final (estilo, frase, primero) in esperados) {
      test('${estilo.nombre} · «$frase» → $primero', () {
        final elegidos = elegidosPara(estilo, frase);

        expect(
          elegidos,
          isNotEmpty,
          reason: 'El entrenador confirmó que «$frase» lleva a $primero',
        );
        expect(
          elegidos.first,
          primero,
          reason: 'Se conserva el orden de prioridad que él declaró',
        );
      });
    }

    test('ninguna de las 40 frases queda sin ejercicio', () {
      final sinEjercicio = <String>[];

      for (final (estilo, frase, _) in esperados) {
        if (elegidosPara(estilo, frase).isEmpty) {
          sinEjercicio.add('${estilo.nombre}: $frase');
        }
      }

      expect(sinEjercicio, isEmpty);
    });
  });

  group('los ejercicios que el entrenador retiró no vuelven', () {
    test('«patada desde las rodillas» no trae CHUTAR EL AGUA', () {
      // Corrige el error contrario: rodillas en extensión. Prescribirlo para
      // este error lo reforzaría.
      expect(
        elegidosPara(Estilo.espalda, 'patada desde las rodillas'),
        isNot(contains('CHUTAR EL AGUA – DOBLAR RODILLA')),
      );
    });

    test('«patada caída» no trae CHUTAR EL AGUA', () {
      expect(
        elegidosPara(Estilo.espalda, 'patada caída'),
        isNot(contains('CHUTAR EL AGUA – DOBLAR RODILLA')),
      );
    });

    test('«brazo flexionado en fase aérea» no trae TOCANDO FRENTE', () {
      // Su ejecución flexiona el codo, que es justo el error a eliminar.
      expect(
        elegidosPara(Estilo.espalda, 'brazo flexionado en fase aérea'),
        isNot(contains('TOCANDO FRENTE')),
      );
    });

    test('«brazos no salen del agua» no trae DELFINEO', () {
      // En DELFINEO los brazos regresan por dentro del agua.
      expect(
        elegidosPara(Estilo.mariposa, 'brazos no salen del agua'),
        isNot(contains('DELFINEO')),
      );
    });

    test('«no lleva las manos hasta adelante» no trae PN EN SOLDADO', () {
      expect(
        elegidosPara(Estilo.mariposa, 'no lleva las manos hasta adelante'),
        isNot(contains('PN EN SOLDADO')),
      );
    });
  });

  group('tolera cómo escribe el entrenador, sin adivinar', () {
    test('da igual el artículo: «desde rodillas» o «desde las rodillas»', () {
      expect(
        elegidosPara(Estilo.espalda, 'patada desde rodillas'),
        elegidosPara(Estilo.espalda, 'patada desde las rodillas'),
      );
    });

    test('da igual la tilde', () {
      expect(
        elegidosPara(Estilo.espalda, 'patada caida'),
        elegidosPara(Estilo.espalda, 'patada caída'),
      );
    });

    test('da igual la mayúscula', () {
      expect(
        elegidosPara(Estilo.libre, 'CABEZA ALTA'),
        elegidosPara(Estilo.libre, 'cabeza alta'),
      );
    });

    test('«dosiflexión» y «dorsiflexión» llevan al mismo ejercicio', () {
      expect(
        elegidosPara(Estilo.pecho, 'dosiflexión'),
        elegidosPara(Estilo.pecho, 'dorsiflexión'),
      );
    });

    test('la frase puede decir más que el término declarado', () {
      expect(
        elegidosPara(Estilo.libre, 'tiene el codo bajo en el recobro'),
        contains('TOCAR AXILA'),
      );
    });

    test('una frase más corta que el término no cuenta', () {
      // «patada» a secas es demasiado genérica para elegir un correctivo.
      expect(
        reportaVacio(Estilo.espalda, 'patada'),
        isTrue,
        reason: 'No debe dar por diagnosticado lo que no está declarado',
      );
    });
  });

  group('la negación no se descarta', () {
    test('«no gira la cadera» y «gira la cadera» no son lo mismo', () {
      expect(
        reportaVacio(Estilo.libre, 'no gira la cadera'),
        isFalse,
        reason: 'Está declarada en el índice',
      );
      expect(
        reportaVacio(Estilo.libre, 'gira la cadera'),
        isTrue,
        reason:
            'Son errores opuestos. Si se descartara el «no», la app '
            'prescribiría lo mismo para los dos',
      );
    });

    test('«no» no está entre las palabras vacías', () {
      expect(palabrasVacias, isNot(contains('no')));
      expect(palabrasVacias, isNot(contains('sin')));
      expect(palabrasVacias, isNot(contains('poco')));
    });
  });

  group('sin índice no se adivina', () {
    test('el selector sin índice reporta vacío para cualquier diagnóstico', () {
      final sinIndice = SelectorEjercicios(cargarBibliotecaReal());
      final seleccion = sinIndice.elegir(
        estilo: Estilo.libre,
        diagnostico: ['cabeza alta'],
        cuantos: 3,
      );

      expect(seleccion.vacios, hasLength(1));
      expect(seleccion.vacios.first.errorDiagnosticado, 'cabeza alta');
    });

    test('una frase que no está declarada se reporta como vacío', () {
      final seleccion = selector.elegir(
        estilo: Estilo.libre,
        diagnostico: ['se cansa muy rápido en los últimos 50'],
        cuantos: 3,
      );

      expect(
        seleccion.vacios,
        hasLength(1),
        reason: 'No se resuelve con un ejercicio aproximado (regla R2)',
      );
    });
  });

  group('palabras significativas', () {
    test('descarta artículos y preposiciones', () {
      expect(palabrasSignificativas('baja las manos hasta la cadera'), {
        'baja',
        'manos',
        'cadera',
      });
    });

    test('normaliza tildes', () {
      expect(palabrasSignificativas('cadera caída'), {'cadera', 'caida'});
    });

    test('un texto sin palabras significativas da conjunto vacío', () {
      expect(palabrasSignificativas('de la en el'), isEmpty);
    });

    test('la ñ se conserva', () {
      expect(palabrasSignificativas('mañana'), {'mañana'});
    });
  });
}
