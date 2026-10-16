# Arquitectura

## Capas

- `lib/core`: configuración compilada, tema, errores, preferencias y utilidades.
- `lib/domain/entities`: objetos inmutables sin dependencia de Supabase.
- `lib/domain/repositories`: contratos testeables para Auth y cada agregado.
- `lib/domain/usecases`: autorización y reglas que no pertenecen a widgets.
- `lib/data/mappers`: traducción tolerante de JSON/relaciones PostgREST.
- `lib/data/repositories`: única implementación que conoce `SupabaseClient`.
- `lib/presentation/controllers`: providers Riverpod, estado Auth y caché de vistas.
- `lib/presentation/pages`: páginas y formularios responsive.
- `lib/presentation/widgets`: shell, estados comunes, buscador y mapas.

Un widget puede invocar un repositorio o use case inyectado, pero nunca construye
una consulta con `Supabase.instance.client.from(...)`.

## Estado y navegación

Riverpod 3 expone repositorios, use cases y estados asíncronos. `go_router` protege
todo el `ShellRoute`: cuando Auth no está autorizado, solo se construye el gate
de acceso. `locked` conserva el `ShellRoute` montado, lo cubre con una barrera y
exige otro TOTP; así no descarta silenciosamente formularios abiertos. La barra
lateral conserva su preferencia local.

El flujo Auth es:

1. restaurar o crear sesión Supabase;
2. leer el perfil por `auth.uid()`;
3. rechazar y cerrar sesión si `role != admin`;
4. consultar assurance level/factores MFA;
5. enrolar o verificar TOTP cuando corresponda;
6. después de verificar MFA, repetir desde el paso 2 y confirmar AAL2 real;
7. construir las rutas administrativas.

El temporizador multiplataforma escucha actividad de puntero, rueda y teclado.
Su duración proviene de `AppConfig.inactivityTimeout` y no almacena passwords ni
implementa criptografía propia.

## Datos y rendimiento

- el dashboard realiza conteos `HEAD` en paralelo;
- flota, conductores, incidencias y viajes paginan en servidor;
- el snapshot de Monitoreo pagina de 500 en 500 para no truncarse al límite de
  filas de PostgREST; parches Realtime agrupan consultas de 100 IDs;
- listados relacionados usan embeds PostgREST para evitar N+1;
- búsquedas esperan 400 ms y se filtran en servidor;
- el mapa escucha un solo canal `admin-vehicle-locations` compartido por provider;
- al cancelar el provider se llama `removeChannel`, evitando canales duplicados;
- el payload extrae `vehicle_id` y agrupa IDs durante 750 ms; se consultan solo
  los IDs cambiados y se mezclan con la lista actual sin perder la cámara;
- el canal informa conectado/reconectando/timeout/error/cerrado; al reconectar
  se recarga la lista completa para no dejar eventos perdidos;
- las unidades sin GPS siguen en lista, pero no generan marcadores;
- cambios de ubicación ya no invalidan métricas independientes de la ubicación.

Las asignaciones conductor/unidad y el reordenamiento nunca encadenan `UPDATE`
desde Flutter. Los repositorios llaman RPC transaccionales; si la propuesta 006
no está instalada, fallan de forma explícita sin fallback parcial.

## Mapas

`TransportMap` encapsula `flutter_map`, el template de tiles y la identificación
del cliente. Las rutas actuales son polilíneas entre paradas ordenadas y no se
presentan como trazado vial. `RouteGeometryService` y su implementación
`StraightLineRouteGeometryService` dejan un punto de sustitución explícito para
un OSRM autoalojado futuro, sin cambiar las entidades de paradas.

## Errores

Las páginas modelan loading, success, empty y error/retry. Los detalles técnicos
no se muestran ni se imprimen en producción. Los formularios validan antes de
invocar los casos de uso. El cliente HTTP limita la espera de respuesta inicial
a 25 segundos y nunca reintenta mutaciones automáticamente. Tras restauración,
refresh o regreso a la app se vuelve a comprobar `profiles.role`.
