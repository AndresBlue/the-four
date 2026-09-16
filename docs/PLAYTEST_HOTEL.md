# Evaluación humana pendiente — hotel y supervivencia

Este documento es un protocolo, no evidencia de pruebas completadas. Los recorridos automatizados prueban colisiones/interacciones, no desorientación, terror, comprensión ni duración humana.

## Veinte recorridos de revisión

Semillas 0–19. Iniciar con `./tools/godot.ps1 playtest -Seed <n>` desde la carpeta del proyecto. Se usa el hotel real y Locust activo. Continuar/reintentar mantiene esa distribución. No se aporta mapa automático.

Para cada semilla registrar fecha, evaluador, duración, llegada al refugio, muertes, bloqueos, habitación difícil de reconocer, captura confusa y acceso de escondites. Estado de las veinte: **pendiente de evaluación humana**.

- Comprobar percepción de hotel: habitaciones familiares, cambios de escala y espacios comunes unidos.
- Buscar cruces repetitivos y tramos sin referencias; diferenciar desorientación intencional de monotonía.
- Entrar y salir de escondites, cerrar/abrir puertas normal y lentamente, evitar un ataque tras el aviso.
- Comparar esconderse tras romper visión frente a entrar ante Locust.
- Entrar al refugio, volver al laberinto y regresar; confirmar protección y salida libre.
- Probar calidad baja, Compatibility, efectos reducidos y música apagada. Las señales esenciales deben seguir siendo comprensibles.

## Cinco partidas completas

Semillas sugeridas 81, 202, 404, 717 y 909. No conocer previamente el recorrido. Registrar tiempo de exploración, persecución percibida, descansos, atascos y causa de cada muerte. Las cinco siguen **pendientes**.

Meta: 25–40 minutos por piso, sin exigir espera. Una salida temprana es válida. Ajustar tamaño y referencias con estos resultados; no atribuir a pruebas automáticas una duración humana.

## Criterios de incidencia

Bloqueante: salida inaccesible, encierro sin salida, captura a través de pared o dentro del refugio, checkpoint cambiado sin aviso. Grave: aviso ilegible, puerta que bloquea permanentemente, escondite que siempre concede inmunidad pese a entrada observada. Visual: repetición excesiva, muebles flotantes, polvo que tape visión, iluminación que borre referencias.
