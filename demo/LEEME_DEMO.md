# Demo de CV UP (feria)

Base de datos propia para la demo, con **datos 100 % ficticios**:
- 5 avisos inventados: Analista de Datos, Atención al Cliente, Comercial B2B, Coordinador Académico y Marketing Digital.
- 294 postulantes inventados: nombres, DNI, correos `@example.com` y teléfonos `900000xxx`.

No usa nada de la base real de GTH. El ranking sí es real: lo calculó el mismo código del sistema (modelo **multilingual e5**). Por eso los puntajes, los requisitos cumplidos, los bonos y las alertas de rotación son los que daría el sistema de verdad.

| Archivo | Qué hace |
|---|---|
| `01_estructura.sql` | Crea tablas, vistas, funciones y permisos. Es el mismo esquema de GTH. **Una sola vez.** |
| `02a_datos_avisos_postulantes.sql` | Avisos y postulantes. También **deja la demo como nueva**: borra lo que los visitantes hayan movido. |
| `02b_datos_ranking.sql` | Ranking e5 de cada postulante |
| `02c1` … `02c5_datos_trayectoria.sql` | Análisis de trayectoria laboral, un archivo por aviso (31 con alerta de rotación) |
| `02d_datos_empresas.sql` | Diccionario de empresas Tier 1 y Tier 1.5 |
| `03_usuario_demo.sql` | Da acceso a la cuenta de la demo |
| `04_fuentes_portales.sql` | Portal de origen de cada postulante (Bumeran, LinkedIn o Computrabajo). Solo si cargaste los `02` antes del 25/11; los nuevos ya lo traen. |
| `05_permisos.sql` | Permisos de la web. Los proyectos nuevos de Supabase ya no los dan solos. Ya viene incluido en `01`; córrelo si cargaste el `01` antes del 25/11. |
| `06_aviso_practicante_rrhh.sql` | Aviso «Practicante de Recursos Humanos» con 3 preseleccionados que tienen una **entrevista en video real** (public/demo/entrevistas/practicante_rrhh_*.mp4, personas que dieron su permiso; los nombres en la web son ficticios). Solo si cargaste los `02` antes del 26/11; los nuevos ya lo traen. |

## 1. Crear el proyecto en Supabase
1. En [supabase.com](https://supabase.com) → **New project**. Elige la región **South America (São Paulo)** y guarda la contraseña de la base.
2. Ve a **Authentication → Sign In / Providers** y desactiva **Allow new users to sign up**. Así ningún visitante puede crearse una cuenta.

## 2. Cargar la base (elige una opción)

**A. Desde el navegador (SQL Editor)**
1. Ve a **SQL Editor → New query**, pega el contenido de `01_estructura.sql` y presiona **Run**.
2. Haz lo mismo con cada archivo de datos, en este orden: `02a`, `02b`, `02c1`, `02c2`, `02c3`, `02c4`, `02c5` y `02d`. Cada uno pesa menos de 750 KB, lo que el editor acepta.

**B. Con un comando (más rápido)**

Copia la cadena de conexión desde **Connect → Session pooler** y corre:

```bash
python demo/cargar_demo.py "postgresql://postgres.xxxx:CLAVE@aws-0-sa-east-1.pooler.supabase.com:5432/postgres"
```

## 3. Crear la cuenta de la demo
1. Ve a **Authentication → Users → Add user → Create new user**. Pon el correo y la contraseña que usarás en el stand y marca **Auto Confirm User**.
2. Abre `03_usuario_demo.sql`, cambia `demo@cvup.pe` por ese correo (aparece 3 veces) y córrelo en el SQL Editor.

   Con la opción B, en cambio, agrega `--cuenta tu@correo` al comando.

La cuenta queda como superadministradora: ve todo, incluidos los sueldos, y no le pide cambiar la contraseña.

## 4. Desplegar en Vercel
1. Sube la carpeta `CV_UP` a tu repositorio y en Vercel elige **Add New → Project** con ese repositorio. Vite se detecta solo.
2. En **Environment Variables** agrega solo estas dos, que están en Supabase, en **Project Settings → API**:

   | Variable | Valor |
   |---|---|
   | `VITE_SUPABASE_URL` | Project URL (`https://xxxx.supabase.co`) |
   | `VITE_SUPABASE_ANON_KEY` | clave `anon` / `public` |

3. **No** agregues `SUPABASE_SERVICE_ROLE_KEY`, `SMTP_*` ni `GEMINI_*`. Así desde el stand nadie puede crear cuentas, enviar correos ni gastar la API de Gemini; esos botones solo mostrarán un aviso.

Para probarlo en tu PC antes, crea `CV_UP/.env.local` con esas dos variables y corre `npm install` y luego `npm run dev`.

## Durante la feria
- **Para dejar todo como al inicio** entre visitas, vuelve a correr todos los `02` en el mismo orden, o usa `python demo/cargar_demo.py "<conexión>" --solo-datos`. Eso borra las etapas, marcas, comentarios y pesos que hayan cambiado los visitantes. La cuenta no se toca.
- **«Recalcular puntaje»** muestra «servidor apagado»: en la demo no hay servidor ni revisión de Bumeran. El ranking que se ve ya viene calculado.
- **Sin CV en PDF:** los postulantes ficticios no tienen PDF adjunto.
- **Plan gratuito:** Supabase pausa los proyectos gratuitos tras una semana sin uso. Entra un par de días antes de la feria para que esté activo.

## Volver a generar los datos (opcional)
Hace falta un Python con `sentence-transformers` y el modelo e5, por ejemplo el `.venv` del proyecto de GTH. Desde la carpeta `CV_UP`:

```bash
python demo/generar_demo.py
```

```bash
node demo/probar_demo.mjs
```

El primer comando rehace todos los `02`; siempre salen las mismas personas ficticias. El segundo prueba todo en un Postgres local, sin tocar Supabase.
