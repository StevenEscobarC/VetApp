# Modelo de dominio de VetApp

Usa estos nombres y reglas como fuente de verdad. Si una tarea necesita un campo o estado que no está aquí, propónlo explícitamente en vez de inventarlo en silencio.

## Contenido
1. Actores y organizaciones
2. Pacientes
3. Citas
4. Registros clínicos
5. Reseñas
6. Invariantes clave

## 1. Actores y organizaciones

**Clinica**
- `id`, `nombre`, `nit`, `direccion`, `ciudad`, `telefono`, `ubicacion` (lat/lng)
- `horarios` (por día de la semana), `servicios` (consulta, vacunación, cirugía, laboratorio, peluquería...)
- `calificacionPromedio`, `totalResenas` (calculados, no editables por el cliente)

**Veterinario**
- `id`, `usuarioId`, `clinicaId`, `nombre`, `tarjetaProfesional`, `especialidades`
- Un veterinario puede pertenecer a una o más clínicas (relación `veterinario_clinica`).

**Propietario** (dueño de mascota)
- `id`, `usuarioId`, `tipoDocumento`, `numeroDocumento`, `nombre`, `telefono`, `email`
- `autorizacionDatos` (fecha, versión de la política aceptada) — obligatoria antes de guardar datos personales.
- No está atado a una clínica: puede tener citas e historias en varias.

## 2. Pacientes

**Mascota**
- `id`, `propietarioId`, `nombre`, `especie` (`perro`, `gato`, `otro`), `razaId` + `razaNombre` (de The Dog/Cat API; `razaNombre` se guarda para no depender de la API)
- `sexo`, `fechaNacimiento` (o edad estimada), `esterilizado`, `color`, `microchip` (15 dígitos, opcional, único)
- `pesoActualKg` (derivado del último registro de peso)

## 3. Citas

**Cita**
- `id`, `clinicaId`, `veterinarioId` (opcional al solicitar), `mascotaId`, `propietarioId`
- `inicio`, `fin` (en `America/Bogota`), `servicio`, `motivo`
- `estado`:

```
solicitada ──► confirmada ──► atendida
     │              │
     └──► cancelada ◄┘          confirmada ──► no_asistio
```

- Solo la clínica confirma, marca `atendida` o `no_asistio`.
- El propietario puede cancelar mientras esté `solicitada` o `confirmada` (la antelación mínima es configuración de la clínica).
- Una `atendida` o `no_asistio` es final.

## 4. Registros clínicos

**Consulta** (entrada de la historia clínica)
- `id`, `mascotaId`, `clinicaId`, `veterinarioId`, `citaId` (opcional), `fecha`
- `anamnesis`, `examenFisico` (temperatura °C, frecuencia cardiaca, frecuencia respiratoria, condición corporal), `pesoKg`, `diagnostico`, `plan`, `observaciones`

**Adenda**: corrección o complemento de una consulta ya cerrada (`consultaId`, `autor`, `fecha`, `texto`).

**Vacunacion / Desparasitacion**
- `producto`, `laboratorio`, `lote`, `fechaAplicacion`, `proximaDosis`, `veterinarioId`

**Receta**
- `id`, `consultaId`, `fecha`, `items` (medicamento, presentación, dosis, frecuencia, vía, duración), `indicaciones`
- Firmada por un veterinario con tarjeta profesional.

**ResultadoLaboratorio**
- `id`, `mascotaId`, `proveedor` (`idexx`, `abaxis`, `otro`), `idExterno`, `fechaMuestra`, `parametros` (nombre, valor, unidad, rango de referencia, bandera alto/bajo), `pdfUrl` (opcional)
- Se inserta solo desde la Edge Function del webhook; `idExterno` es único para que los reintentos del webhook no dupliquen resultados.

## 5. Reseñas

**Resena**
- `id`, `clinicaId`, `propietarioId`, `citaId`, `calificacion` (1–5), `comentario`, `fecha`, `respuestaClinica` (opcional)

## 6. Invariantes clave

- Una consulta cerrada **no se edita ni se borra**; los cambios van como adenda. La historia clínica es un registro con valor legal y debe mostrar qué se escribió, quién y cuándo.
- Una reseña requiere una cita propia en estado `atendida`, y solo hay una reseña por cita.
- Un veterinario no puede tener dos citas `confirmada` que se solapen.
- Un microchip no puede estar asociado a dos mascotas.
- Un propietario solo ve sus mascotas; una clínica solo ve historias de pacientes que ha atendido o que el propietario compartió con ella.
- Los pesos se guardan en kg; las temperaturas en °C.
