import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';

/// Invariantes de `Cuenta`, de `data-model.md`.
void main() {
  group('una cuenta de entrenador no es un nadador', () {
    test('construirla con nadadorId no se permite', () {
      expect(
        () => Cuenta(id: 'u1', rol: Rol.entrenador, nadadorId: 'n1'),
        throwsArgumentError,
        reason: 'Si el entrenador quiere entrenarse a sí mismo, eso es una '
            'segunda cuenta, no un campo. Permitirlo haría que «los registros '
            'de su comunidad» se solapara con «sus propios registros», y las '
            'reglas de acceso tendrían dos respuestas para la misma pregunta',
      );
    });

    test('sin nadadorId es válida', () {
      final entrenador = Cuenta(id: 'u1', rol: Rol.entrenador);
      expect(entrenador.esEntrenador, isTrue);
      expect(entrenador.nadadorId, isNull);
    });
  });

  group('una cuenta de nadador sin perfil asociado es válida', () {
    test('se construye y se puede usar', () {
      // Es el día en que alguien se registra antes de que su entrenador lo
      // inscriba. No es un error: es un estado normal de la app.
      final recienLlegado = Cuenta(id: 'u2', rol: Rol.nadador);

      expect(recienLlegado.esNadador, isTrue);
      expect(recienLlegado.sinPerfilAsociado, isTrue);
    });

    test('al asociarle un perfil deja de estar suelta', () {
      final cuenta = Cuenta(id: 'u2', rol: Rol.nadador);
      expect(cuenta.copiarCon(nadadorId: 'n1').sinPerfilAsociado, isFalse);
    });
  });

  group('una cuenta sin identificador no es una cuenta', () {
    test('vacío no se permite', () {
      expect(() => Cuenta(id: '', rol: Rol.nadador), throwsArgumentError);
    });

    test('solo espacios tampoco', () {
      expect(() => Cuenta(id: '   ', rol: Rol.nadador), throwsArgumentError);
    });
  });

  group('el rol no se declara desde el cliente', () {
    test('las claves son exactamente las que viajan en el token', () {
      expect(Rol.porClave('entrenador'), Rol.entrenador);
      expect(Rol.porClave('nadador'), Rol.nadador);
    });

    test('cualquier otra cosa es null y no se interpreta', () {
      for (final basura in ['admin', 'Entrenador', 'ENTRENADOR', '', ' ']) {
        expect(
          Rol.porClave(basura),
          isNull,
          reason: '«$basura» no es un rol. Resolverlo al más parecido sería '
              'exactamente como se cuela un permiso',
        );
      }
    });

    test('un token sin rol tampoco se resuelve al menos peligroso', () {
      expect(Rol.porClave(null), isNull);
    });
  });

  group('igualdad', () {
    test('dos cuentas con los mismos datos son la misma', () {
      expect(
        Cuenta(id: 'u1', rol: Rol.nadador, nadadorId: 'n1'),
        Cuenta(id: 'u1', rol: Rol.nadador, nadadorId: 'n1'),
      );
    });

    test('cambiar el perfil asociado la hace distinta', () {
      expect(
        Cuenta(id: 'u1', rol: Rol.nadador, nadadorId: 'n1'),
        isNot(Cuenta(id: 'u1', rol: Rol.nadador, nadadorId: 'n2')),
      );
    });
  });
}
