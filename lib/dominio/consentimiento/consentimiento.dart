/// El consentimiento: el título que ampara tratar los datos de un nadador.
///
/// Lo que este tipo promete y lo que no:
///
/// > Es **demostrable, no infalsificable**. Permite probar qué se autorizó,
/// > por quién según su propia declaración, cuándo y bajo qué texto. **No**
/// > prueba la identidad de quien confirmó, y **no** exime al entrenador de su
/// > responsabilidad como Responsable del Tratamiento bajo la Ley 1581 de
/// > 2012.
///
/// Está dicho aquí, en la especificación y en el checklist. Tres veces a
/// propósito: es lo primero que alguien va a dar por sentado.
///
/// Contrato: `specs/004-cuentas-y-consentimiento/contracts/consentimiento.md`.
library;

/// Qué tratamiento cubre un consentimiento.
///
/// Son alcances **distintos** y conceder uno no concede el otro (FR-023). El
/// video no entra en esta feature, pero su alcance se modela desde ahora:
/// descubrirlo después obligaría a volver a pedirle el consentimiento a todas
/// las familias.
enum Alcance {
  datosDeEntrenamiento('datosDeEntrenamiento'),
  video('video');

  const Alcance(this.clave);

  final String clave;

  static Alcance? porClave(String? clave) {
    for (final alcance in Alcance.values) {
      if (alcance.clave == clave) return alcance;
    }
    return null;
  }
}

/// Quién otorga, según su propia declaración.
///
/// **Nada de esto está verificado.** Son declaraciones, y lo que el sistema
/// registra es quién declaró qué y cuándo. El tipo se llama así, y no
/// `Acudiente`, porque llamarlo acudiente afirmaría algo que no se comprobó.
class Otorgante {
  const Otorgante({
    required this.nombre,
    required this.documento,
    required this.calidad,
    this.esElPropioNadador = false,
  });

  /// El nadador mayor de edad que consiente por sí mismo (FR-024).
  const Otorgante.elPropioNadador({
    required this.nombre,
    required this.documento,
  })  : calidad = 'el propio nadador',
        esElPropioNadador = true;

  final String nombre;
  final String documento;

  /// Padre, madre, acudiente… Texto libre: la realidad de quién cuida a un
  /// niño no cabe en una lista cerrada.
  final String calidad;

  final bool esElPropioNadador;

  bool get estaCompleto =>
      nombre.trim().isNotEmpty &&
      documento.trim().isNotEmpty &&
      calidad.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is Otorgante &&
      other.nombre == nombre &&
      other.documento == documento &&
      other.calidad == calidad &&
      other.esElPropioNadador == esElPropioNadador;

  @override
  int get hashCode =>
      Object.hash(nombre, documento, calidad, esElPropioNadador);
}

/// Se intentó construir un consentimiento que no ampara nada.
class ConsentimientoSinAlcance implements Exception {
  const ConsentimientoSinAlcance();

  @override
  String toString() =>
      'Un consentimiento que no cubre ningún tratamiento no ampara nada. '
      'Registrarlo daría por autorizado algo que nadie autorizó.';
}

/// Falta la constancia de que el menor fue oído.
class MenorNoOido implements Exception {
  const MenorNoOido();

  @override
  String toString() =>
      'El Decreto 1377 de 2013 exige que el menor sea oído antes de que su '
      'representante legal autorice el tratamiento de sus datos.';
}

class Consentimiento {
  Consentimiento({
    required this.nadadorId,
    required this.otorgadoPor,
    required this.otorgadoEn,
    required this.alcances,
    required this.versionDelTexto,
    required this.menorFueOido,
    this.revocadoEn,
  }) {
    if (alcances.isEmpty) throw const ConsentimientoSinAlcance();

    // Solo se exige cuando consiente un tercero por el nadador. Un mayor de
    // edad que consiente por sí mismo no tiene a quién oír.
    if (!otorgadoPor.esElPropioNadador && !menorFueOido) {
      throw const MenorNoOido();
    }
  }

  final String nadadorId;
  final Otorgante otorgadoPor;

  /// **Fecha del servidor**, nunca la del dispositivo (FR-017).
  ///
  /// Es un dato legal. Si la pusiera el teléfono, bastaría cambiar el reloj
  /// para fechar una autorización en cualquier día.
  final DateTime otorgadoEn;

  final Set<Alcance> alcances;

  /// Bajo qué versión del texto informativo se otorgó (FR-018).
  ///
  /// Cambiar el texto no reescribe retroactivamente lo que alguien aceptó.
  final String versionDelTexto;

  /// Constancia de que el menor fue oído (FR-021).
  ///
  /// Es la constancia de una declaración, no la verificación de un hecho.
  final bool menorFueOido;

  final DateTime? revocadoEn;

  /// **Se deriva, no se escribe.** Un campo propio podría contradecir a la
  /// fecha de revocación, y entonces la puerta tendría dos respuestas.
  bool get vigente => revocadoEn == null;

  bool cubre(Alcance alcance) => vigente && alcances.contains(alcance);

  /// Revoca sin borrar el pasado (FR-022).
  ///
  /// `otorgadoEn` y `otorgadoPor` sobreviven: ese registro es la prueba de que
  /// el tratamiento anterior estuvo amparado. Borrarlo al revocar destruiría
  /// justamente la evidencia que protege al entrenador.
  Consentimiento revocar(DateTime cuando) => Consentimiento(
        nadadorId: nadadorId,
        otorgadoPor: otorgadoPor,
        otorgadoEn: otorgadoEn,
        alcances: alcances,
        versionDelTexto: versionDelTexto,
        menorFueOido: menorFueOido,
        revocadoEn: cuando,
      );

  @override
  String toString() =>
      'Consentimiento($nadadorId, vigente: $vigente, '
      'alcances: ${alcances.map((a) => a.clave).join(', ')})';
}
