/// Perfil de nadador.
///
/// Datos mínimos para planificar. El principio V de la constitución exige
/// recolectar solo lo que tiene un uso declarado en la feature.
///
/// **Restricción vigente**: mientras no exista el registro de consentimiento
/// del acudiente, solo deben cargarse perfiles de prueba o del propio
/// entrenador. Ver `spec.md`, sección Assumptions.
library;

import 'package:natacion_app/dominio/cuentas/edad.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Marca registrada de un nadador.
class Marca {
  const Marca({
    required this.distancia,
    required this.estilo,
    required this.tiempo,
    required this.fecha,
  });

  final int distancia;
  final Estilo estilo;
  final Duration tiempo;
  final DateTime fecha;

  /// Formato `mm:ss.cc`.
  String get tiempoLegible {
    final minutos = tiempo.inMinutes;
    final segundos = tiempo.inSeconds % 60;
    final centesimas = (tiempo.inMilliseconds % 1000) ~/ 10;
    return '$minutos:${segundos.toString().padLeft(2, '0')}'
        '.${centesimas.toString().padLeft(2, '0')}';
  }
}

/// Lo que impide dar el perfil por completo.
class FaltaEnPerfil {
  const FaltaEnPerfil(this.campo, this.descripcion);

  final String campo;
  final String descripcion;

  @override
  String toString() => descripcion;
}

class Nadador {
  const Nadador({
    this.id,
    required this.nombre,
    this.fechaNacimiento,
    this.declaraSerMayorDeEdad,
    this.categoria,
    this.estiloObjetivo,
    this.pruebaObjetivo = '',
    this.marcas = const <Marca>[],
    this.diagnosticoTecnico = const <String>[],
    this.comunidadId,
    this.miembroDesde,
    this.pertenenciaTerminadaEn,
  });

  final String? id;
  final String nombre;
  final DateTime? fechaNacimiento;

  /// Lo que el nadador declaró sobre su mayoría de edad (FR-008).
  ///
  /// Es **el dato mínimo suficiente** para saber si hace falta el
  /// consentimiento de un acudiente, y por eso se prefiere a la fecha de
  /// nacimiento, que dice bastante más de lo que hace falta (minimización,
  /// principio V).
  ///
  /// `null` significa **que todavía no lo declaró**, que no es lo mismo que
  /// ser menor. Ante `null` se trata como menor, porque el error de pedir un
  /// consentimiento que no hacía falta se arregla; el de no pedirlo, no.
  final bool? declaraSerMayorDeEdad;

  /// Si hace falta el consentimiento de un acudiente.
  ///
  /// Nada de esto determina la **categoría** del nadador. La categoría se
  /// declara por habilidades y nunca por la edad (sección 11.1 de la
  /// metodología 3.6.0): un niño y un adulto pueden entrenar en Iniciación.
  /// Delega en `dominio/cuentas/edad.dart` (garantía A4).
  ///
  /// El orden cambió con la feature 006: antes mandaba la declaración y ahora
  /// manda **la fecha de nacimiento cuando la hay**. Solo se nota en un caso
  /// —alguien que declaró ser mayor y cuya fecha dice que no— y ahí la
  /// respuesta nueva es la prudente: se pide el consentimiento.
  bool necesitaAcudienteEn(DateTime referencia) => necesitaAcudiente(
    nacimiento: fechaNacimiento,
    declaraSerMayorDeEdad: declaraSerMayorDeEdad,
    referencia: referencia,
  );

  /// Obligatoria para dar el perfil por completo: sin ella no se puede validar
  /// el volumen de sus sesiones.
  final Categoria? categoria;

  /// Obligatorio para dar el perfil por completo: sin él no se puede validar
  /// la distribución de estilos.
  final Estilo? estiloObjetivo;

  final String pruebaObjetivo;
  final List<Marca> marcas;

  /// Errores técnicos observados. Alimenta el criterio C10.
  final List<String> diagnosticoTecnico;

  /// A qué comunidad pertenece, si pertenece a alguna (feature 012).
  ///
  /// **Esto es la pertenencia, y vive aquí y en ningún otro sitio.** No se
  /// copia en sus registros, ni en sus planes, ni en sus peticiones, y esa es
  /// la decisión que sostiene la feature entera: terminar una pertenencia
  /// tiene que cortar la lectura **de inmediato**, y una copia es algo que
  /// todavía puede dar la respuesta vieja.
  ///
  /// Es, palabra por palabra, lo que la puerta de consentimiento de la feature
  /// 004 ya dejó escrito: desnormalizarlo crearía la posibilidad de que el
  /// estado discrepe de sí mismo en dos sitios.
  ///
  /// **Nulo significa que no es de nadie**, y no hay un tercer valor: si está
  /// esperando, eso lo dice su solicitud, no esto. Dos sitios para la misma
  /// pregunta son dos sitios que pueden contestar distinto.
  final String? comunidadId;

  /// Desde cuándo. Nulo si no pertenece a ninguna.
  final DateTime? miembroDesde;

  /// Cuándo dejó de pertenecer, si alguna vez perteneció (FR-026).
  ///
  /// **Para que ella se entere sin tener que preguntarle a nadie.** Que la
  /// saquen de un grupo sin que nadie lo diga es la clase de cosa que se
  /// descubre un martes al abrir la app y no encontrar el plan.
  ///
  /// No dice quién ni por qué: es un dato sobre su cuenta, no sobre el
  /// entrenador. Un motivo escrito viajando hasta ella sería un texto libre
  /// sobre una persona, con las mismas pegas que FR-011 ya pesó para el
  /// rechazo.
  final DateTime? pertenenciaTerminadaEn;

  /// Si pertenece a la comunidad de quien pregunta.
  ///
  /// La pregunta que hace toda la feature 012, en un sitio.
  bool esDeLaComunidad(String? comunidadDeQuienPregunta) =>
      comunidadId != null &&
      comunidadDeQuienPregunta != null &&
      comunidadId == comunidadDeQuienPregunta;

  /// Edad en años cumplidos, si se conoce la fecha de nacimiento.
  ///
  /// Delega en `dominio/cuentas/edad.dart`, que es **el único sitio** donde se
  /// calcula esto (garantía A4). Desde la feature 006 hay dos datos que podrían
  /// contestar la pregunta, y dos cálculos serían dos sitios donde
  /// equivocarse.
  int? edadEn(DateTime referencia) => edadA(fechaNacimiento, referencia);

  /// Verdadero si se sabe que es menor de edad.
  ///
  /// Devuelve `null` cuando no hay fecha de nacimiento: no se supone la edad.
  bool? esMenorEn(DateTime referencia) => esMenorA(fechaNacimiento, referencia);

  List<FaltaEnPerfil> get faltas {
    final faltas = <FaltaEnPerfil>[];

    if (nombre.trim().isEmpty) {
      faltas.add(const FaltaEnPerfil('nombre', 'Falta el nombre del nadador'));
    }
    if (categoria == null) {
      faltas.add(
        const FaltaEnPerfil(
          'categoria',
          'Falta la categoría: sin ella no se puede validar el volumen',
        ),
      );
    }
    if (estiloObjetivo == null) {
      faltas.add(
        const FaltaEnPerfil(
          'estiloObjetivo',
          'Falta el estilo objetivo: sin él no se puede validar la '
              'distribución de estilos',
        ),
      );
    }

    return faltas;
  }

  bool get estaCompleto => faltas.isEmpty;

  Nadador copiarCon({
    String? id,
    String? nombre,
    DateTime? fechaNacimiento,
    bool? declaraSerMayorDeEdad,
    Categoria? categoria,
    Estilo? estiloObjetivo,
    String? pruebaObjetivo,
    List<Marca>? marcas,
    List<String>? diagnosticoTecnico,
  }) {
    return Nadador(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      declaraSerMayorDeEdad:
          declaraSerMayorDeEdad ?? this.declaraSerMayorDeEdad,
      categoria: categoria ?? this.categoria,
      estiloObjetivo: estiloObjetivo ?? this.estiloObjetivo,
      pruebaObjetivo: pruebaObjetivo ?? this.pruebaObjetivo,
      marcas: marcas ?? this.marcas,
      diagnosticoTecnico: diagnosticoTecnico ?? this.diagnosticoTecnico,
    );
  }
}
