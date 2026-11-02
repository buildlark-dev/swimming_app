/// Propuestas de ejercicio pendientes de aprobación.
///
/// Regla R2 de la metodología: si la Biblioteca no cubre una necesidad técnica
/// detectada, **no se improvisa**. Se señala el vacío y la sugerencia va en un
/// bloque separado, fuera de la planificación. Solo se incorpora si el
/// entrenador la aprueba y se añade a la Biblioteca.
library;

import 'package:natacion_app/dominio/metodologia/estilos.dart';

enum EstadoPropuesta {
  pendiente('Pendiente de aprobación'),
  aprobada('Aprobada'),
  rechazada('Rechazada');

  const EstadoPropuesta(this.nombre);

  final String nombre;
}

class PropuestaEjercicio {
  const PropuestaEjercicio({
    this.id,
    required this.nombrePropuesto,
    required this.descripcion,
    required this.estilo,
    required this.motivo,
    required this.fecha,
    this.estado = EstadoPropuesta.pendiente,
  });

  final String? id;
  final String nombrePropuesto;
  final String descripcion;
  final Estilo estilo;

  /// Qué vacío de la Biblioteca pretende cubrir.
  final String motivo;

  final DateTime fecha;
  final EstadoPropuesta estado;

  /// Una propuesta NUNCA forma parte de un plan, cualquiera que sea su estado.
  /// Para entrar en un plan tiene que estar antes en la Biblioteca Oficial.
  bool get puedeUsarseEnUnPlan => false;

  PropuestaEjercicio copiarCon({String? id, EstadoPropuesta? estado}) {
    return PropuestaEjercicio(
      id: id ?? this.id,
      nombrePropuesto: nombrePropuesto,
      descripcion: descripcion,
      estilo: estilo,
      motivo: motivo,
      fecha: fecha,
      estado: estado ?? this.estado,
    );
  }
}

/// Registro de propuestas, separado de los planes.
class RegistroPropuestas {
  final List<PropuestaEjercicio> _propuestas = [];
  int _siguienteId = 1;

  List<PropuestaEjercicio> get todas => List.unmodifiable(_propuestas);

  List<PropuestaEjercicio> get pendientes =>
      _propuestas.where((p) => p.estado == EstadoPropuesta.pendiente).toList();

  PropuestaEjercicio registrar(PropuestaEjercicio propuesta) {
    final conId = propuesta.copiarCon(id: 'propuesta-${_siguienteId++}');
    _propuestas.add(conId);
    return conId;
  }

  /// Aprobar una propuesta **no** la incorpora a la Biblioteca: solo deja
  /// constancia de la decisión. Incorporarla exige editar el documento
  /// normativo y subir su versión, según el flujo de la constitución.
  void marcar(String id, EstadoPropuesta estado) {
    final indice = _propuestas.indexWhere((p) => p.id == id);
    if (indice == -1) return;
    _propuestas[indice] = _propuestas[indice].copiarCon(estado: estado);
  }
}
