# Traccar

Este repositorio contiene las imágenes y unidades de Podman para ejecutar
[Traccar](https://www.traccar.org/) junto con PostgreSQL/TimescaleDB. Traccar
recibe las posiciones de los dispositivos GPS; TimescaleDB almacena el
historial y aplica políticas configurables de compresión y retención.

El despliegue Quadlet ejecuta ambos contenedores en el mismo pod. La base de
datos escucha solo dentro del pod, mientras que los puertos del servidor
Traccar quedan publicados en el host. Para instrucciones completas de
instalación, configuración, historial y optimización, consulta
[quadlet/README.md](./quadlet/README.md).

## Componentes

- `traccar/`: imagen basada en Traccar 6.16.0 y su configuración versionada.
- `traccar-db/`: imagen basada en TimescaleDB para PostgreSQL 17, con las
  extensiones `timescaledb` y `pg_stat_statements`, además de las políticas
  de historial.
- `quadlet/`: definición del pod y los contenedores, y ejemplos de variables
  de entorno para el despliegue con systemd y Podman.

## Requisitos

- Podman y systemd con soporte para Quadlet.
- Un servidor con conectividad a los dispositivos GPS y espacio suficiente
  para la base de datos y sus copias de seguridad.
- Acceso de administrador para instalar las unidades y configurar el firewall.

## Construir las imágenes

Ejecuta desde la raíz del repositorio:

```sh
podman build -t localhost/unitrack-traccar:6.16.0 \
  -f traccar/Containerfile traccar/
podman build -t localhost/unitrack-traccar-db:pg17 \
  -f traccar-db/Containerfile traccar-db/
```

Las unidades Quadlet usan estas etiquetas locales y están configuradas para no
descargar imágenes automáticamente (`Pull=never`).

## Instalación rápida con Quadlet

1. Copia `quadlet/traccar.env.example` y
   `quadlet/traccar-db.env.example` a `/etc/unitrack/traccar.env` y
   `/etc/unitrack/traccar-db.env`.
2. Sustituye `REPLACE_WITH_A_SECRET` por una contraseña fuerte e idéntica en
   ambos archivos. Protege los archivos, por ejemplo con
   `sudo chmod 600 /etc/unitrack/traccar.env /etc/unitrack/traccar-db.env`.
3. Copia `quadlet/traccar.pod`, `quadlet/traccar.container` y
   `quadlet/traccar-db.container` a `/etc/containers/systemd/`.
4. Recarga systemd e inicia los servicios:

   ```sh
   sudo systemctl daemon-reload
   sudo systemctl start traccar-pod.service traccar-db.service traccar.service
   ```

5. Comprueba el estado con `systemctl status traccar.service traccar-db.service`.

El pod publica `8082/tcp` (interfaz web), `5055/tcp` y los puertos de
dispositivos `5000-5200/tcp` y `5000-5200/udp`. Ajusta el firewall a los
protocolos y dispositivos que uses; restringe especialmente el acceso a la
interfaz web en `8082`. PostgreSQL usa el puerto `5432` dentro del pod y no se
publica directamente en el host.

Los datos persisten en los volúmenes de Podman `unitrack-traccar-db` y
`unitrack-traccar-logs`. Haz copias de seguridad periódicas de la base antes de
actualizar imágenes, modificar las políticas de historial o cambiar los
volúmenes.

## Configuración del historial

En `/etc/unitrack/traccar-db.env` (a partir de
`quadlet/traccar-db.env.example`) puedes ajustar:

- `TRACCAR_COMPRESSION_DAYS`: días antes de comprimir datos (14 por defecto).
- `TRACCAR_RETENTION_DAYS`: días que se conservan los datos (90 por defecto).

El valor `0` desactiva la política correspondiente. La compresión debe ser
menor que la retención cuando ambas están activas. Las políticas se aplican a
las tablas de posiciones y eventos después de que Traccar las crea.

