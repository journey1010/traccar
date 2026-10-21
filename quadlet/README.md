# Traccar y TimescaleDB

Este grupo contiene el pod y los dos contenedores. Traccar y TimescaleDB
comparten el pod; la base solo escucha dentro
del pod y no publica `5432` en el host. Los puertos públicos del pod son
`8082/tcp`, `5055/tcp` y `5000-5200/tcp+udp`, igual que en Compose. Restringe
`8082` con el firewall del servidor para que el panel no quede abierto a
Internet.

## Imágenes

Construye ambas imágenes desde la raíz del repositorio. La imagen de Traccar
incluye `traccar.xml`; la de TimescaleDB habilita TimescaleDB y
`pg_stat_statements` para inspeccionar estadísticas de consultas.

```sh
podman build -t localhost/unitrack-traccar:6.16.0 -f traccar/Containerfile traccar/
podman build -t localhost/unitrack-traccar-db:pg17 -f traccar-db/Containerfile traccar-db/
```

El repositorio ya tenía una imagen propia para la base, con TimescaleDB; esta
unidad Quadlet la consume y añade estadísticas de consultas. `pg_stat_statements`
no es la telemetría anónima de Traccar: permite consultar tiempos y conteos de
ejecución de las sentencias SQL.

## Configuración e inicio

Copia `traccar.env.example` y `traccar-db.env.example` a
`/etc/unitrack/traccar.env` y `/etc/unitrack/traccar-db.env`. Usa una contraseña
segura e idéntica en ambos; limita los archivos a lectura del administrador
(`chmod 0600`). No copies los `.env` locales del repositorio al servidor.

Copia `traccar.pod`, `traccar.container` y `traccar-db.container` a
`/etc/containers/systemd/`, y luego arranca el pod:

```sh
sudo systemctl daemon-reload
sudo systemctl start traccar-pod.service traccar-db.service traccar.service
```

Las unidades esperan que los contenedores reporten estado saludable antes de
marcarse listos. `traccar.service` además espera a `traccar-db.service`.

La configuración inicial contempla ≈1,000 dispositivos reportando cada 30 s,
con uso moderado del panel: Traccar tiene pool DB de 30 y timeout de conexión
GPS de 60 s; el contenedor fija `nofile` en 50,000. En UniTrack, el pool inicial
del API es 20 conexiones y el worker conserva 30. Las llamadas REST de UniTrack
a Traccar y la apertura de conexiones DB esperan hasta 20 s. Estos son valores
iniciales para esa carga; revisa métricas antes de escalar réplicas o aumentar
los pools.

Los valores `DATABASE_MAX_POOL_SIZE`, `SERVER_TIMEOUT` y
`DATABASE_REGISTER_UNKNOWN` del ejemplo Quadlet corresponden a los defaults
del `traccar/traccar.xml` de Compose. Así ambos despliegues parten de la misma
capacidad y evitan que dispositivos desconocidos se registren solos. El
healthcheck de TimescaleDB usa `pg_isready` sin credenciales codificadas; el
entrypoint de PostgreSQL sigue creando la base y el usuario desde
`traccar-db.env`, y la contraseña debe coincidir con `traccar.env`.

La extensión y `pg_stat_statements` se instalan automáticamente solo al crear
una base nueva. Si se reutiliza un volumen existente, verifica las extensiones
con `\dx`; si falta `pg_stat_statements`, créala como superusuario después de
reiniciar PostgreSQL con la nueva imagen.

## Historial y optimización

La imagen de la base aplica políticas de TimescaleDB sobre `tc_positions` y
`tc_events` (`traccar-db/apply-policies.sh`): compresión a los
`TRACCAR_COMPRESSION_DAYS` (14 por defecto) y borrado a los
`TRACCAR_RETENTION_DAYS` (90 por defecto); `0` desactiva la política. Se
configuran en `traccar-db.env` y se reaplican en cada arranque del contenedor.
Las hypertables las crea Traccar en su primer inicio, así que las políticas se
aplican cuando existen, no al inicializar la base. La opción antigua de Traccar
`database.historyDays` fue retirada. La documentación de
[optimización](https://www.traccar.org/optimization/) recomienda ajustar el
motor de base y sus límites al volumen real; los parámetros de memoria siguen
sin valores arbitrarios.

## Referencias

- [Requisitos de servidores](../../../docs/requisitos-servidores.md)
- [Configuración oficial de Traccar](https://www.traccar.org/configuration-file)
- [Limpieza del historial en Traccar](https://www.traccar.org/clear-history/)
- [Optimización de Traccar](https://www.traccar.org/optimization/)
- [Estadísticas `pg_stat_statements`](https://www.postgresql.org/docs/current/pgstatstatements.html)
