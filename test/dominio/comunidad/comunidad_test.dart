/// La comunidad rechaza lo que no puede representar.
///
/// Y una cosa más, que es la que importa para el resto de la feature:
/// **cambiarle el nombre no mueve a nadie**. El nombre vive en la comunidad y
/// la pertenencia vive en el perfil de cada nadadora, justo para que eso sea
/// cierto sin que nadie tenga que acordarse (FR-003).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/comunidad.dart';

void main() {
  Comunidad conNombre(String nombre) =>
      Comunidad(id: 'c1', entrenadorId: 'e1', nombre: nombre);

  test('un nombre en blanco no es un nombre', () {
    expect(() => conNombre(''), throwsA(isA<NombreDeComunidadInvalido>()));
    expect(() => conNombre('   '), throwsA(isA<NombreDeComunidadInvalido>()));
    expect(
      () => conNombre('\n\t '),
      throwsA(isA<NombreDeComunidadInvalido>()),
    );
  });

  test('se recortan los espacios de los lados', () {
    expect(conNombre('  Club Acuático  ').nombre, 'Club Acuático');
  });

  test('sesenta caracteres caben; sesenta y uno, no', () {
    final justo = 'a' * largoMaximoDelNombre;
    expect(conNombre(justo).nombre, justo);

    expect(
      () => conNombre('a' * (largoMaximoDelNombre + 1)),
      throwsA(isA<NombreDeComunidadInvalido>()),
      reason:
          'el nombre existe para que ella lo reconozca en su pantalla, y uno '
          'que se parte no lo cumple',
    );
  });

  test('renombrar conserva de quién es y desde cuándo', () {
    final cuando = DateTime(2026, 11, 19);
    final original = Comunidad(
      id: 'c1',
      entrenadorId: 'e1',
      nombre: 'Antes',
      creadaEn: cuando,
    );

    final despues = original.renombrada('Después');

    expect(despues.nombre, 'Después');
    expect(despues.id, 'c1');
    expect(
      despues.entrenadorId,
      'e1',
      reason:
          'una comunidad que pudiera cambiar de manos es otro producto, y uno '
          'con preguntas que este no se ha hecho: qué pasa con lo que el '
          'anterior leyó, y con lo que las familias consintieron',
    );
    expect(despues.creadaEn, cuando);
  });

  test('renombrar valida igual que crear', () {
    final original = conNombre('Antes');
    expect(
      () => original.renombrada(''),
      throwsA(isA<NombreDeComunidadInvalido>()),
    );
  });

  test('no hay forma de cambiarle el entrenador', () {
    // El control negativo de la de arriba, y vive en lo que la clase **no**
    // ofrece: no hay `conEntrenador`, ni un `copiarCon` que lo acepte. Si
    // alguien añade uno, esta prueba sigue en verde y por eso está escrita
    // aquí — para que quien lo añada lea por qué no estaba.
    final comunidad = conNombre('Club');
    expect(comunidad.entrenadorId, 'e1');
  });
}
