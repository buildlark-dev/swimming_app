/// Los campos de formulario, decididos una vez.
///
/// El desplegable es el que justifica este archivo. `isExpanded: true` hubo que
/// ponerlo **siete veces a mano** en las features anteriores, y cada vez fue
/// después de que una prueba cazara un desborde de veintisiete píxeles. Aquí es
/// lo que hace el componente, y nadie tiene que acordarse.
///
/// La altura y el relleno los pone el tema. Estos componentes no los tocan: lo
/// intentamos en la fase 2 y desbordó seis desplegables.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

/// Un campo de texto.
class Campo extends StatelessWidget {
  const Campo({
    super.key,
    required this.etiqueta,
    this.controlador,
    this.valorInicial,
    this.pista,
    this.ayuda,
    this.problema,
    this.alCambiar,
    this.lineas = 1,
    this.esClave = false,
    this.tipoDeTeclado,
    this.validar,
  });

  final String etiqueta;
  final TextEditingController? controlador;

  /// Lo que el campo trae escrito al aparecer.
  ///
  /// Hace falta para que **volver atrás en un recorrido no borre nada**: sin
  /// esto el campo se reconstruye vacío aunque el dato siga guardado, y quien
  /// vuelve cree que lo perdió. Lo cazó la prueba C2 del alta.
  final String? valorInicial;

  /// Ejemplo de lo que se espera, dentro del campo.
  final String? pista;

  /// Explicación bajo el campo, cuando la etiqueta no basta.
  final String? ayuda;

  /// Lo que está mal. Si no es nulo, el campo se muestra en error.
  final String? problema;

  final ValueChanged<String>? alCambiar;

  /// Más de una para el texto largo: la notación del entrenador ocupa varias.
  final int lineas;

  final bool esClave;
  final TextInputType? tipoDeTeclado;
  final String? Function(String?)? validar;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      // `TextFormField` no admite las dos cosas a la vez.
      initialValue: controlador == null ? valorInicial : null,
      obscureText: esClave,
      keyboardType: tipoDeTeclado,
      maxLines: lineas,
      minLines: lineas > 1 ? lineas : null,
      onChanged: alCambiar,
      validator: validar,
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: pista,
        helperText: ayuda,
        errorText: problema,
      ),
    );
  }
}

/// Un desplegable de opciones.
///
/// `isExpanded` va puesto y **no se puede quitar**: es la razón de que este
/// componente exista.
class CampoDeOpciones<T> extends StatelessWidget {
  const CampoDeOpciones({
    super.key,
    required this.etiqueta,
    required this.opciones,
    required this.nombreDe,
    required this.alCambiar,
    this.valor,
    this.pista,
  });

  final String etiqueta;
  final List<T> opciones;

  /// Cómo se llama cada opción en la pantalla. El vocabulario visible es del
  /// entrenador, no del código.
  final String Function(T) nombreDe;

  final ValueChanged<T?> alCambiar;
  final T? valor;
  final String? pista;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: valor,
      hint: pista == null ? null : Text(pista!),
      decoration: InputDecoration(labelText: etiqueta),
      items: [
        for (final opcion in opciones)
          DropdownMenuItem(value: opcion, child: Text(nombreDe(opcion))),
      ],
      onChanged: alCambiar,
    );
  }
}

/// Una fila de opciones cortas, para elegir una.
///
/// Para lo que no merece un desplegable: el esfuerzo percibido del 0 al 10, que
/// el nadador marca con el dedo mojado.
class OpcionesEnFila<T> extends StatelessWidget {
  const OpcionesEnFila({
    super.key,
    required this.opciones,
    required this.nombreDe,
    required this.alElegir,
    this.elegida,
  });

  final List<T> opciones;
  final String Function(T) nombreDe;
  final ValueChanged<T> alElegir;
  final T? elegida;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Espaciado.corto,
      runSpacing: Espaciado.corto,
      children: [
        for (final opcion in opciones)
          ChoiceChip(
            label: Text(nombreDe(opcion)),
            selected: elegida == opcion,
            onSelected: (_) => alElegir(opcion),
          ),
      ],
    );
  }
}
