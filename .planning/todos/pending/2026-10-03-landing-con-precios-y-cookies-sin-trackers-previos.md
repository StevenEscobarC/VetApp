---
created: 2026-10-03T05:08:22.752Z
title: Landing con precios y cookies sin trackers previos
area: general
files: []
---

## Problem

VetApp no tiene página web de captación. De la competencia auditada vale la pena adoptar:
- Una página de precios clara: comparativa de planes, alternancia mensual/anual, FAQ, "sin tarjeta".
- Etiquetas honestas de "Próximamente".
- Un selector "¿Quién eres?" (veterinario / dueño).
- Una calculadora pública de vacunas como imán de tráfico.

Todos los competidores fallan en cookies: cargan Meta Pixel y GA antes del consentimiento o tienen un "Rechazar" que no hace nada.

## Solution

- Hacer la landing estática después de decidir la marca, con un formulario de contacto por WhatsApp o lista de espera.
- Mostrar solo funciones entregadas; el resto va como "Próximamente".
- Analítica: preferir una sin cookies (Plausible/Umami). Si se usa GA4/Pixel: Consent Mode v2, cero trackers antes de elegir, "Rechazar" igual de visible que "Aceptar" y política de cookies coherente con lo que carga el código.
- Los precios salen de la estrategia de negocio vigente (carpeta local, no versionada).
- Siguientes pasos: calculadora de vacunas con protocolos de Colombia y páginas SEO por ciudad (directorio de la Fase 9).
