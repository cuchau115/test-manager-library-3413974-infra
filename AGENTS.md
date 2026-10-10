# AGENTS.md — repo `infra` (Docker Compose)

> **Lee primero el plan maestro completo:** `../AGENTS.md` (raíz del proyecto). Copia canónica
> versionada: `../test-manager-library-3413974-docs/AGENTS.md`. Este archivo es solo un puntero.

## Reglas duras (resumen; detalle en el maestro §1)
- El motor arranca **vacío**: prohibido DDL/`CREATE TABLE` aquí (ADR-001).
- **Un solo comando** levanta todo: `docker compose up --build` desde `infra`.
- Servicios `db` (postgres:16), `api`, `app`, `page`; `tool` como perfil opcional.
- Secretos solo por entorno; se versiona solo `.env.example`.
- **Commits pequeños** (`infra: …`) y **push** al fork `cuchau115/test-manager-library-3413974-infra`.
- Toda tarea exige **evidencia** reproducible.

## Estado actual del trabajo
- [*] `INFRA-02` servicios API, React y página estática agregados; `docker compose config --quiet` y `docker compose build app page` pasan.
- [*] `INFRA-03` completado: red `library`, volúmenes `db-data`/`covers` y healthchecks; app/page/db/api reportan `healthy` al ejecutar Compose.
- [*] `INFRA-05` completado: README documenta el arranque con `docker compose up --build -d`; API saludable y administrador inicial validado.
- [*] `INFRA-06` completado: `.\verify-e2e.ps1` prueba login, préstamo, devolución y reporte mediante curl dentro del contenedor `api`.
- `/` responde `{"status":"ok"}`; `SESSION_DRIVER=file` evita la consulta a la tabla ausente, y `APP_DEBUG=false` no expone trazas.

## Tareas de este repo (maestro §9.7)
`INFRA-01`…`INFRA-06`. Modelo: `opencode/deepseek-v4-pro`.
Dependencias: `INFRA-02`←(T-01.2,APP-11,PAGE-04); `INFRA-05`←T-17.3; `INFRA-06`←(APP-10,TOOL-03).
