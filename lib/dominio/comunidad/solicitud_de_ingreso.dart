/// Una nadadora pidiendo una pertenencia que todavía no existe.
///
/// Lo que la feature 008 hizo con las peticiones de plan, hecho aquí: ella
/// levanta algo, espera donde el entrenador ya mira, y **nada ocurre sin la
/// firma de él**.
///
/// ## Lo que este tipo rechaza, para que no lo tenga que rechazar una pantalla
///
/// `aceptada` es una palabra del entrenador. La copia de la nadadora puede
/// pasar a `retirada` y a ningún otro sitio, y eso se comprueba aquí y no en el
/// widget que dibuja el botón: un cerrojo que viviera en una pantalla sería un
/// cerrojo en una puerta de tres, que es como la feature 009 lo aprendió.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

enum EstadoDeSolicitud {
  /// Pedida, sin contestar. Es el único estado en que el entrenador la ve en
  /// su cola.
  esperando('esperando'),

  /// Él dijo que sí. La pertenencia existe desde ese momento.
  aceptada('aceptada'),

  /// Él dijo que no. **No es una prohibición**: ella puede volver a pedir, aquí
  /// o en otro sitio (FR-012).
  rechazada('rechazada'),

  /// Ella se arrepintió antes de que contestaran.
  retirada('retirada');

  const EstadoDeSolicitud(this.clave);

  /// Lo que se guarda. Si esta cadena cambia, cambia también en las reglas.
  final String clave;

  static EstadoDeSolicitud? porClave(String? clave) {
    for (final estado in EstadoDeSolicitud.values) {
      if (estado.clave == clave) return estado;
    }
    return null;
  }

  bool get estaEsperando => this == EstadoDeSolicitud.esperando;

  /// Si ya se resolvió, de la manera que sea.
  bool get estaResuelta => !estaEsperando;
}

/// Qué hay que retirar antes de pedir entrar en [aDonde] (FR-008).
///
/// **Una nadadora tiene como mucho una solicitud esperando.** Pedir en otro
/// sitio es cambiar de idea, no pedir dos veces: dos entrenadores con la misma
/// solicitud delante pueden aceptarla los dos, y entonces la pertenencia —que
/// vive en un solo sitio— decide por orden de llegada quién se queda con ella.
/// Nadie habría elegido eso; sería el resultado de no haber elegido nada.
///
/// Devuelve la que hay que retirar, o nula si no hay nada que retirar:
///
/// - Sin solicitud anterior, nada.
/// - Si la anterior ya está resuelta, nada: no ocupa sitio.
/// - **Si la anterior es a la misma comunidad, nada**, y esto importa más de
///   lo que parece. El identificador es determinista, así que volver a pedir
///   en el mismo sitio reescribe el mismo documento; retirarlo primero sería
///   dejarlo en `retirada` un instante por un reintento sin señal.
///
/// Esto vive aquí y no dentro del repositorio para poder comprobarse sin
/// servidor (principio II). El repositorio lo usa; la decisión es del dominio.
SolicitudDeIngreso? laQueHayQueRetirar(
  SolicitudDeIngreso? anterior,
  String aDonde,
) {
  if (anterior == null) return null;
  if (anterior.estado.estaResuelta) return null;
  if (anterior.comunidadId == aDonde) return null;
  return anterior;
}

class TransicionNoEsSuya implements Exception {
  const TransicionNoEsSuya(this.porQue);

  final String porQue;

  @override
  String toString() => 'Esa transición no le corresponde: $porQue';
}

class SolicitudDeIngreso {
  SolicitudDeIngreso({
    required this.nadadorId,
    required this.comunidadId,
    required this.pedidaEn,
    this.nombre = '',
    this.estado = EstadoDeSolicitud.esperando,
    this.resueltaEn,
  });

  /// Cómo se llama quien pide, dicho por ella misma.
  ///
  /// **La solicitud lo lleva dentro, y tiene que llevarlo.** La garantía F3
  /// dice que antes de aceptar el entrenador no lee **nada** de ella «más allá
  /// de lo que la propia solicitud lleva», y FR-009 dice que vea quién le pidió
  /// entrar. Las dos cosas solo son ciertas a la vez si el nombre viaja aquí:
  /// con el nombre en su ficha —que él todavía no puede leer, y no debe— la
  /// cola le enseñaba «Alguien que todavía no tiene perfil» y le pedía decidir
  /// sobre una desconocida. Lo encontró el recorrido del quickstart.
  ///
  /// Lo escribe ella al pedir, sobre su propia solicitud, que es lo único que
  /// la regla le deja crear. Vacío si no se pudo leer; la pantalla lo dice en
  /// lugar de inventarlo.
  final String nombre;

  /// Quién pidió.
  final String nadadorId;

  /// Dónde pidió entrar.
  final String comunidadId;

  final DateTime pedidaEn;

  final EstadoDeSolicitud estado;

  /// Cuándo dejó de esperar. Nulo mientras espera.
  final DateTime? resueltaEn;

  /// El identificador, determinista.
  ///
  /// Pedir dos veces es pedir lo mismo, y un reintento sin señal no puede
  /// crear dos solicitudes. Es la misma forma que la feature 010 usó para las
  /// peticiones de feedback y por la misma razón.
  String get id => '$nadadorId|$comunidadId';

  /// **Lo único que ella puede hacerle.**
  SolicitudDeIngreso retirada(DateTime cuando) {
    if (estado.estaResuelta) {
      throw const TransicionNoEsSuya('ya estaba resuelta');
    }
    return _con(EstadoDeSolicitud.retirada, cuando);
  }

  /// Del entrenador. Aquí para poder probarla; quien la llama en producción es
  /// el servidor, porque aceptar escribe también la pertenencia y las dos
  /// cosas tienen que pasar juntas o ninguna.
  SolicitudDeIngreso aceptada(DateTime cuando) {
    if (estado.estaResuelta) {
      throw const TransicionNoEsSuya('ya estaba resuelta');
    }
    return _con(EstadoDeSolicitud.aceptada, cuando);
  }

  /// Del entrenador. **Sin motivo escrito**: no se le debe una explicación a
  /// quien todavía no es su nadadora, y un texto libre viajando hasta una
  /// desconocida es un problema sin ninguna ventaja.
  SolicitudDeIngreso rechazada(DateTime cuando) {
    if (estado.estaResuelta) {
      throw const TransicionNoEsSuya('ya estaba resuelta');
    }
    return _con(EstadoDeSolicitud.rechazada, cuando);
  }

  SolicitudDeIngreso _con(EstadoDeSolicitud otro, DateTime cuando) =>
      SolicitudDeIngreso(
        nadadorId: nadadorId,
        comunidadId: comunidadId,
        pedidaEn: pedidaEn,
        nombre: nombre,
        estado: otro,
        resueltaEn: cuando,
      );

  @override
  String toString() => 'SolicitudDeIngreso($id, ${estado.clave})';
}
