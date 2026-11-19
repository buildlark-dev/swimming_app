/// Que una nadadora pertenece a una comunidad, y desde cuándo.
///
/// **Es un valor, no un documento.** En el almacén esto son dos campos en el
/// perfil de la nadadora —`comunidadId` y `miembroDesde`—, y este tipo es lo
/// que significan juntos.
///
/// Que viva en un solo sitio es la decisión que sostiene la feature entera
/// (research D1): terminar una pertenencia tiene que cortar la lectura **de
/// inmediato**, y una copia en cada registro, cada plan y cada petición es un
/// conjunto de cosas que todavía pueden dar la respuesta vieja. Es, palabra por
/// palabra, lo que la puerta de consentimiento ya dejó escrito en la feature
/// 004: desnormalizarlo crearía la posibilidad de que el estado discrepe de sí
/// mismo en dos sitios.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

class Membresia {
  const Membresia({
    required this.nadadorId,
    required this.comunidadId,
    required this.desde,
  });

  final String nadadorId;
  final String comunidadId;
  final DateTime desde;

  /// Si esta pertenencia deja leer a quien pregunta.
  ///
  /// La pregunta que hace toda la feature, en un sitio.
  bool laPuedeLeer(String comunidadDeQuienPregunta) =>
      comunidadId == comunidadDeQuienPregunta;

  @override
  bool operator ==(Object other) =>
      other is Membresia &&
      other.nadadorId == nadadorId &&
      other.comunidadId == comunidadId &&
      other.desde == desde;

  @override
  int get hashCode => Object.hash(nadadorId, comunidadId, desde);

  @override
  String toString() => 'Membresia($nadadorId en $comunidadId)';
}

/// Dónde está una nadadora respecto de pertenecer a algo.
///
/// **No es un estado de la pertenencia: son cuatro hechos distintos sobre
/// ella**, y la pantalla necesita los cuatro para no decirle algo falso.
///
/// Esto no entra en el `Lectura` de la feature 011 a propósito (research D6).
/// Aquello dice si *la lectura* terminó; esto dice qué se encontró. Meterlos en
/// un mismo tipo repetiría, con otro disfraz, el defecto que la 011 arregló:
/// un valor con dos significados y una pantalla eligiendo el más contundente.
sealed class DondeEsta {
  const DondeEsta();
}

/// Pertenece, y estas son las credenciales para leerla.
class Pertenece extends DondeEsta {
  const Pertenece(this.membresia);

  final Membresia membresia;
}

/// Pidió entrar y nadie ha contestado. **Entra igual a la app**: lo que no
/// tiene todavía es plan, y eso es lo que la pantalla le explica (FR-020).
class Esperando extends DondeEsta {
  const Esperando(this.comunidadId);

  final String comunidadId;
}

/// No ha pedido entrar a ningún sitio. No está esperando nada, y decirle que
/// espera sería mentirle (FR-021).
class NoHaPedido extends DondeEsta {
  const NoHaPedido();
}

/// Pidió y le dijeron que no. Puede volver a pedir, aquí o en otro sitio.
class LeDijeronQueNo extends DondeEsta {
  const LeDijeronQueNo(this.comunidadId);

  final String comunidadId;
}
