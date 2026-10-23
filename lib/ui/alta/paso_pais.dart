/// Paso 3: de dónde viene.
///
/// **Es opcional** (FR-009). El país se pide para que el club lo sepa y para
/// nada más: un dato que no decide nada no bloquea a nadie, y una prueba de
/// frontera vigila que siga siendo así.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

/// Los países desde donde se usa la app, y uno para no decirlo.
///
/// La lista es corta a propósito: crece cuando alguien la necesite, no por si
/// acaso. Quien no esté puede no decirlo, y no pierde nada por ello.
const paisesConocidos = <String, String>{
  'CO': 'Colombia',
  'AR': 'Argentina',
  'BR': 'Brasil',
  'CL': 'Chile',
  'EC': 'Ecuador',
  'ES': 'España',
  'MX': 'México',
  'PE': 'Perú',
  'US': 'Estados Unidos',
  'UY': 'Uruguay',
  'VE': 'Venezuela',
};

class PasoPais extends StatelessWidget {
  const PasoPais({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAlta>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿De dónde eres?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Espaciado.corto),
        const Text(
          'Es para que el club sepa de dónde viene cada nadador. No cambia '
          'nada de tu entrenamiento, y puedes no decirlo.',
        ),
        const SizedBox(height: Espaciado.seccion),
        CampoDeOpciones<String>(
          key: const Key('alta-campo-pais'),
          etiqueta: 'Tu país',
          pista: 'Prefiero no decirlo',
          valor: estado.perfil.pais,
          opciones: paisesConocidos.keys.toList(),
          nombreDe: (codigo) => paisesConocidos[codigo] ?? codigo,
          alCambiar: estado.escribirPais,
        ),
      ],
    );
  }
}
