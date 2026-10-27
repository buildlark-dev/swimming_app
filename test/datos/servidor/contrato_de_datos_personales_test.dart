/// Que el cliente y el servidor hablen de lo mismo, en las dos operaciones
/// nuevas de la feature 007.
///
/// Mismo método que el contrato de la 006, y por la misma razón: **los dobles
/// implementan la interfaz de Dart, no el cable**. Diez pruebas del camino del
/// acudiente pasaban en verde mientras el cuerpo iba mal formado.
///
/// Aquí hay además un cerrojo que no es de forma, sino de fondo: **la palabra
/// `terminos` no puede aparecer en `corregirPerfil`**. Si apareciera, corregir
/// un apellido reescribiría la constancia de qué versión aceptó una persona y
/// cuándo, que es un registro legal y no un campo más.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';

void main() {
  final ruta = File('firebase/functions/src/datos_personales.ts');

  group('la prueba no pasa por vacía', () {
    test('el fuente del servidor existe', () {
      expect(
        ruta.existsSync(),
        isTrue,
        reason:
            'Sin este archivo no hay nada que comprobar, y el contrato '
            'pasaría en verde sin servidor',
      );
    });
  });

  final servidor = ruta.existsSync() ? ruta.readAsStringSync() : '';

  /// El bloque de una función exportada, hasta la siguiente.
  String bloqueDe(String nombre) {
    final desde = servidor.indexOf(nombre);
    if (desde < 0) return '';
    final siguiente = servidor.indexOf('\nexport ', desde + nombre.length);
    return servidor.substring(
      desde,
      siguiente < 0 ? servidor.length : siguiente,
    );
  }

  group('corregirPerfil — el cuerpo que se manda es el que se lee', () {
    final cuerpo = cuerpoDeCorreccion(
      nombre: 'María Fernanda Gallón',
      fechaNacimiento: DateTime.utc(2014, 3, 7),
      pais: 'CO',
    );

    final bloque = bloqueDe('export async function corregirPerfilDe');

    test('los tres campos van en la raíz, con estos nombres', () {
      expect(cuerpo.keys.toSet(), {'nombre', 'fechaNacimiento', 'pais'});

      for (final campo in ['nombre', 'fechaNacimiento', 'pais']) {
        expect(
          bloque,
          contains(campo),
          reason: 'El servidor no desempaqueta «$campo»',
        );
      }
    });

    test('la fecha va como AAAA-MM-DD, que es lo que el servidor parsea', () {
      expect(cuerpo['fechaNacimiento'], '2014-03-07');
    });

    test('el país puede ir nulo: no decide nada y no bloquea a nadie', () {
      final sinPais = cuerpoDeCorreccion(
        nombre: 'Juan Restrepo',
        fechaNacimiento: DateTime.utc(1995, 4, 12),
        pais: null,
      );

      expect(sinPais['pais'], isNull);
      expect(sinPais.containsKey('pais'), isTrue);
    });

    test('**no se manda la versión de los términos**', () {
      expect(
        cuerpo.containsKey('versionDeTerminos'),
        isFalse,
        reason:
            'Esta operación no puede estampar una aceptación: es la '
            'diferencia con `guardarPerfil`',
      );
    });

    test('**y la palabra `terminos` no aparece en el servidor**', () {
      // El cerrojo más importante de la feature. `guardarPerfil` escribe
      // `terminos: { version, aceptadaEn: serverTimestamp() }`, y si esta
      // función hiciera lo mismo, corregir un apellido diría que la persona
      // aceptó hoy la versión vigente, cuando aceptó otra hace un mes y nadie
      // le ha mostrado la nueva.
      expect(
        bloque.toLowerCase(),
        isNot(contains('terminos')),
        reason:
            'Corregir el perfil no puede tocar la constancia de qué '
            'versión se aceptó ni cuándo (H21)',
      );
    });

    test('no acepta un uid del cliente: solo se corrige el propio', () {
      expect(cuerpo.containsKey('uid'), isFalse);
      expect(
        bloque,
        isNot(contains('data.uid')),
        reason:
            'Un uid que viene del cliente es un uid que alguien puede '
            'apuntar a otra persona',
      );
    });

    test('escribe en los dos sitios donde vive el nombre (H22)', () {
      // En minúsculas: las colecciones se nombran con constantes
      // (`COL_USUARIOS`), y lo que importa es que las dos aparezcan.
      expect(bloque.toLowerCase(), contains('usuarios'));
      expect(
        bloque.toLowerCase(),
        contains('nadadores'),
        reason:
            'Si solo escribiera en `usuarios`, el panel del entrenador '
            'seguiría mostrando el nombre viejo',
      );
    });
  });

  group('suprimirMisDatos — el cuerpo y lo que exige', () {
    final cuerpo = cuerpoDeSupresion();
    final bloque = bloqueDe('export async function suprimirDatosDe');
    final envoltorio = bloqueDe('export const suprimirMisDatos');

    test('el cuerpo es la confirmación, y nada más', () {
      expect(cuerpo, {'confirmado': true});
    });

    test('**no acepta a quién borrar**', () {
      expect(cuerpo.containsKey('uid'), isFalse);
      expect(cuerpo.containsKey('nadadorId'), isFalse);
      expect(
        envoltorio,
        isNot(contains('data.nadadorId')),
        reason:
            'Una supresión que acepta un identificador es una supresión '
            'que alguien puede dirigir contra otra persona',
      );
    });

    test('el servidor exige `confirmado === true`', () {
      expect(
        envoltorio,
        contains('confirmado'),
        reason:
            'El segundo paso de la confirmación tiene que llegar hasta '
            'aquí: una llamada suelta no borra nada (H27)',
      );
      expect(
        envoltorio,
        contains('confirmado !== true'),
        reason: 'Y se rechaza salvo que venga exactamente `true`',
      );
    });

    test('borra las cuatro cosas, en el orden del dominio', () {
      // **El orden de los borrados**, no el de las menciones: la función lee
      // `usuarios` al principio para resolver el `nadadorId`, y eso no es un
      // borrado.
      final borrados = <String, int>{
        'sus registros': bloque.indexOf('registros.docs.map'),
        'sus asignaciones': bloque.indexOf('asignaciones.docs.map'),
        'su ficha de nadador': bloque.indexOf('nadador.delete()'),
        'el documento de su cuenta': bloque.indexOf('usuario.delete()'),
      };

      borrados.forEach((que, donde) {
        expect(donde, greaterThan(-1), reason: 'No se borra $que');
      });

      expect(
        borrados.values.toList(),
        borrados.values.toList()..sort(),
        reason:
            'El mismo orden que `DerechosDelTitular.eliminar`: primero lo '
            'que el nadador escribió, al final el vínculo de la cuenta. Al '
            'revés, un fallo a mitad dejaría registros sin dueño: datos de '
            'alguien que ya no se puede identificar para borrarlos',
      );
    });

    test('revoca el consentimiento **sin borrar su historial** (H27)', () {
      expect(bloque.toLowerCase(), contains('consentimientos'));
      expect(
        bloque,
        contains('historial'),
        reason:
            'El historial es la prueba de que el tratamiento anterior '
            'estuvo amparado (garantía C8 de la 004), y se conserva a '
            'propósito; nombrarlo aquí obliga a decir qué se hace con él',
      );
    });

    test('borra también la cuenta de identidad (decisión D7)', () {
      expect(
        bloque,
        contains('deleteUser'),
        reason:
            'El correo es un dato personal: dejar la cuenta viva '
            'convertiría el derecho de supresión en un vaciado',
      );
    });
  });
}
