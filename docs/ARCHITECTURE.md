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
todo el `ShellRoute`: cuando Auth no está en `authenticated`, solo se construye el
gate de acceso. La barra lateral conserva su preferencia local.

El flujo Auth es:

1. restaurar o crear sesión Supabase;
2. leer el perfil por `auth.uid()`;
3. rechazar y cerrar sesión si `role != admin`;
4. consultar assurance level/factores MFA;
5. enrolar o verificar TOTP cuando corresponda;
6. construir las rutas administrativas.

## Datos y rendimiento

- el dashboard realiza conteos `HEAD` en paralelo;
- flota pagina en servidor y selecciona solo columnas necesarias;
- listados relacionados usan embeds PostgREST para evitar N+1;
- búsquedas esperan 400 ms y se filtran en servidor;
- el mapa escucha un solo canal `admin-vehicle-locations` por página activa;
- al cancelar el provider se llama `removeChannel`, evitando canales duplicados;
- cada evento invalida únicamente vehículos monitoreados/métricas pertinentes.

## Mapas

`TransportMap` encapsula `flutter_map`, el template de tiles y la identificación
del cliente. Las rutas actuales son polilíneas entre paradas ordenadas y no se
presentan como trazado vial. `RouteGeometryService` y su implementación
`StraightLineRouteGeometryService` dejan un punto de sustitución explícito para
un OSRM autoalojado futuro, sin cambiar las entidades de paradas.

## Errores

Las páginas modelan loading, success, empty y error/retry. Los detalles técnicos
no se muestran ni se imprimen en producción. Los formularios validan antes de
invocar los casos de uso.
