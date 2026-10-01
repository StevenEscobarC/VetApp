# Fase 5 — Protocolos de vacunación y desparasitación (Colombia)

**Fecha:** 2026-10-01 · **Origen:** agente `vetapp-opportunity-research` durante el discuss de la Fase 5 · Semilla para el catálogo base de protocolos (05-CONTEXT D-01..D-04, D-11).

## Resumen

- WSAVA 2024 y la práctica colombiana coinciden en la estructura: una serie primaria cada 2 a 4 semanas hasta las 16 semanas o más, un refuerzo a los 12 meses y luego refuerzos periódicos. En Colombia el refuerzo es casi siempre anual, y la antirrábica también se aplica cada año por norma operativa local, aunque el producto esté aprobado para 3 años.
- La entidad actual `vacuna.dart` tiene `proximaDosis` editable (líneas 38 y 41-45) y una ventana fija de 7 días, lo que contradice el Pitfall 7. Además, al enum `TipoBiologico` le faltan `bordetella`, `polivalenteQuintuple` y `puppyDP`.
- Recomendación: un intervalo por defecto por biológico, con un selector de duración (chips) al registrar. Nunca un campo de fecha libre.

## 1. Protocolos por especie

Edad en semanas, intervalo en días. Cuando hay un rango, el primer valor es el que se propone como predeterminado.

### Perro

| Biológico | Edad mínima 1ª dosis | Dosis de la serie | Intervalo de la serie | Refuerzo | Notas |
|---|---|---|---|---|---|
| Puppy DP (parvovirus + moquillo) | 6 sem | 1 | — (luego polivalente a las 8-9 sem) | — | Primera vacuna habitual en Colombia, entre los 42 y 45 días |
| Polivalente: quíntuple / séxtuple / óctuple | 8 sem | 3 (8, 12 y 16 sem aprox.) | 21 días (14-28) | 12 meses y luego anual | Según WSAVA, la última dosis va a las 16 sem o más. En Colombia es anual por la leptospirosis que incluye. La composición cambia según el laboratorio |
| Parvovirus (monovalente) | 6 sem | según esquema | 14-21 días | anual | Poco frecuente como producto suelto |
| Moquillo (monovalente) | 6 sem | según esquema | 14-21 días | anual | Poco frecuente como producto suelto |
| Leptospirosis (sola) | 8 sem | 2 | 21-28 días | anual | Es "core" en zonas endémicas, que incluyen casi toda Colombia |
| Bordetella / tos de las perreras | 8 sem (intranasal: desde 3 sem) | 1 (intranasal u oral) o 2 (inyectable) | 14-28 días | anual | Las guarderías la exigen. Aplicar al menos 72 h antes del contacto con otros perros |
| Antirrábica | 12 sem | 1 | — | anual en Colombia (algunos productos permiten 3 años) | Para viajar se exigen 21 días desde la primera dosis |
| Desparasitación interna | 2 sem | cada 15 días hasta las 8 sem, luego mensual hasta los 6 meses | 14 → 30 días | adulto: cada 3 meses (ESCCAP) | La serie depende de la edad |
| Desparasitación externa | según producto (normalmente 8 sem) | — | — | 30 días (Frontline/NexGard), 35 días (Simparica), 84 días (Bravecto) | El intervalo lo define el producto |

### Gato

| Biológico | Edad mínima 1ª dosis | Dosis de la serie | Intervalo de la serie | Refuerzo | Notas |
|---|---|---|---|---|---|
| Triple felina | 8 sem (6 sem en algunos productos) | 2-3, hasta las 16 sem o más | 21-28 días | 12 meses y luego anual | En Colombia el protocolo es anual |
| Leucemia felina (FeLV) | 8 sem | 2 | 21-28 días | al año y luego anual (o cada 2-3 años con riesgo bajo) | "Core" para gatos jóvenes o con acceso a la calle. Se recomienda la prueba FeLV antes de vacunar |
| Antirrábica | 12 sem | 1 | — | anual | — |
| Desparasitación interna | 3 sem | cada 15 días hasta las 8-9 sem, luego mensual hasta los 6 meses | 14 → 30 días | adulto: cada 3 meses | — |
| Desparasitación externa | según producto | — | — | 30 días (pipeta) / 84 días (Bravecto gatos) | Filtrar productos por especie: algunos de perro son tóxicos para gatos (permetrina) |

Los intervalos por defecto elegidos dentro de cada rango son suposiciones. Hay que validarlos con 2 o 3 veterinarios usuarios.

## 2. Aspectos legales y prácticos

- **Antirrábica:** en la práctica es obligatoria, dentro del control de zoonosis (Ley 9 de 1979; Decreto 780 de 2016; Circular MinSalud 0064 de 2014). Revacunación anual. No se encontró el artículo exacto que impone la obligación al propietario, así que la app no debe citar texto legal sin verificarlo.
- **ICA, Resolución 100164 de 2021** (viajes):
  - El certificado debe incluir producto, lote, fecha de administración y fecha de revacunación o vigencia.
  - Para la primera antirrábica, deben pasar 21 días o más antes del embarque.
  - Se exige desparasitación interna y externa dentro de los 60 días previos.
  - El certificado lleva firma y matrícula Comvezcol del veterinario, y no puede tener más de 5 días al viajar.
- **Guarderías, hoteles y peluquerías:** piden el carné al día con polivalente, antirrábica, bordetella, desparasitación de no más de 3 meses y antipulgas vigente.

## 3. Variación por producto (sin fricción)

1. Protocolos semilla de solo lectura (`tipo`, `especie`, `edad_min_dias`, `dosis_serie`, `intervalo_serie_dias`, `intervalo_refuerzo_dias`, `opciones_duracion`), más sobrescrituras por clínica (decisión D-01: catálogo editable).
2. Al registrar, el veterinario toca el biológico y la app infiere si es dosis 1/3, 2/3 o refuerzo según el historial y la edad. Muestra "Próxima: dd/mm/aaaa" ya calculada.
3. La variación se elige con chips: antirrábica 1 año (por defecto) o 3 años; desparasitante externo 1 mes, 5 semanas o 3 meses (lo ideal es que el producto elegido fije el intervalo); desparasitante interno según la edad.
4. Autocompletado con los últimos 5 productos usados y su último lote.
5. Si una dosis de la serie se retrasa, la siguiente se calcula desde la fecha real. Si pasan más de 6 semanas entre dosis de la serie, o más de 18 meses desde la última leptospirosis, se sugiere "reiniciar serie". Es solo una sugerencia, nunca un bloqueo.

## 4. Ventanas de alerta

| Estado | Refuerzo anual o trianual | Dosis de serie | Desparasitación |
|---|---|---|---|
| Próxima | 14 días antes | 3 días antes | 5 días antes |
| Vencida | desde D+1 | desde D+1 | desde D+1 |
| Atrasada (sugerir revisar o reiniciar) | más de D+30 | más de D+14 | — |

Decisión del usuario (05-CONTEXT D-11): usar la ventana por tipo de dosis. Es una propuesta de producto, no una norma.

## Fuentes

- WSAVA 2024 Vaccination Guidelines — https://wsava.org/wp-content/uploads/2024/05/2024-Guidelines-for-the-Vaccination-of-Dogs-and-Cats.pdf
- Resolución ICA 100164 de 2021 — https://normograma.invima.gov.co/compilacion/docs/resolucion_ica_100164_2021.htm
- Circular MinSalud 0064 de 2014 — https://normograma.invima.gov.co/normograma/docs/pdf/circular_minsaludps_0064_2014.pdf
- Bogotá, vacunación antirrábica gratuita — https://bogota.gov.co/mi-ciudad/salud/requisitos-para-la-vacunacion-gratuita-de-animales-contra-rabia-bogota
- El Tiempo, vacunas obligatorias para perros — https://www.eltiempo.com/vida/mascotas/cuales-son-las-vacunas-obligatorias-para-los-perros-589759
- Agronegocios, vacunas para cachorros — https://www.agronegocios.co/mascotas/las-vacunas-primerizas-que-no-debe-olvidar-en-el-calendario-para-perros-cachorros-2814436
- colombia.com, esquema de vacunación en gatos — https://www.colombia.com/mascotas/noticias/cual-es-el-esquema-completo-de-vacunacion-para-los-gatos-406989
- ESCCAP, recomendaciones generales — https://www.esccap.org/uploads/docs/zeaqazlq_0797_ESCCAP_General_Recommendations_ES_v2.pdf
- Merck, Nobivac 3-Rabies — https://www.merck-animal-health-usa.com/products/nobivac-3-rabies/
