-- =============================================================================================
-- CV UP · 01 Estructura de la base (tablas, vistas, funciones y permisos).
-- Es el esquema del scraper (scraping/supabase_esquema.sql) más todas las migraciones de supabase/migrations, en orden.
-- Correr UNA sola vez en un proyecto de Supabase nuevo y vacío (SQL Editor -> pegar -> Run).
-- Generado desde el repo: no editar a mano; si cambian las migraciones, volver a generarlo.
-- =============================================================================================

-- >>> scraping/supabase_esquema.sql
-- =============================================================================================
-- Esquema del scraper de Bumeran para Supabase.
-- Cómo usarlo: Supabase -> SQL Editor -> pegar todo este archivo -> Run. Se puede volver a correr.
--
-- Quién accede:
--   * El scraper (PC con Chrome) se conecta con SUPABASE_DB_URL (rol postgres): no pasa por RLS.
--     Esa clave solo va en scraping/.env de esa PC.
--   * Los PDFs NO se guardan en Supabase: van al Google Drive de ESAN; aquí solo su id y enlace.
--   * La web usa la clave pública "anon" + Supabase Auth: solo usuarios con sesión iniciada
--     (rol authenticated) pueden leer. Sin sesión no se ve nada (datos personales, Ley 29733).
-- =============================================================================================

create table if not exists public.avisos (
    aviso_id              text primary key,
    titulo                text,
    estado                text,
    publicado_el          text,                 -- AAAA-MM-DD
    creado_por            text,
    visitas               integer,
    recibidos             integer,              -- contador de Bumeran en la última lectura de la lista
    no_leidos             integer,
    recibidos_al_scrapear integer,              -- valor de 'recibidos' cuando se bajó el último CSV
    url_publica           text,
    url_postulantes       text,
    detalle_json          jsonb,
    detalle_texto         text,
    detalle_at            timestamptz,
    ultimo_csv_at         timestamptz,          -- "Actualizado hace ..."
    ultimo_cvs_at         timestamptz,
    ultima_revision_at    timestamptz,
    primera_vez_at        timestamptz,
    en_ultima_lista       integer default 1
);

create table if not exists public.postulaciones (
    aviso_id          text not null references public.avisos(aviso_id) on delete cascade,
    clave             text not null,            -- DOC:<documento> | MAIL:<correo> | HASH:<...>
    id_postulante     text,                     -- ID legible (alopez888): nombre del PDF y llave con el CSV
    documento         text,
    email             text,
    nombre            text,
    apellido          text,
    fecha_postulacion text,
    datos_json        jsonb not null,           -- fila completa del CSV (94 columnas)
    en_ultimo_csv     integer default 1,
    primera_vez_at    timestamptz,
    actualizado_at    timestamptz,
    primary key (aviso_id, clave)
);

create table if not exists public.cvs (
    aviso_id        text not null references public.avisos(aviso_id) on delete cascade,
    card_id         text not null,              -- id de la tarjeta en la lista de postulantes
    id_postulacion  text,
    id_cv           text,
    documento       text,
    email           text,
    tiene_adjunto   integer,
    archivo         text,                       -- ruta local en la PC del scraper
    drive_id        text,                       -- id del PDF en Google Drive
    drive_url       text,                       -- enlace para abrir el PDF en Google Drive
    estado          text,                       -- descargado | sin_adjunto | error
    error           text,
    actualizado_at  timestamptz,
    primary key (aviso_id, card_id)
);

create table if not exists public.scrape_runs (
    id        bigint generated always as identity primary key,
    tipo      text,                             -- corrida | lista | csv | detalle | cvs | ...
    aviso_id  text,
    inicio    timestamptz,
    fin       timestamptz,
    estado    text,                             -- en_curso | ok | error | interrumpido
    nuevos    integer,
    total     integer,
    mensaje   text
);

-- Pedidos de la web al scraper ("Actualizar"). No hay servidor encendido todo el día: el scraper
-- los toma cuando la PC con Chrome está prendida; mientras tanto quedan como 'pendiente'.
create table if not exists public.solicitudes (
    id           bigint generated always as identity primary key,
    tipo         text not null default 'actualizar'
                 check (tipo in ('actualizar', 'revisar', 'csv', 'oferta', 'pdfs')),
    aviso_id     text,                          -- null = todos los avisos publicados
    estado       text not null default 'pendiente'
                 check (estado in ('pendiente', 'en_curso', 'ok', 'error')),
    mensaje      text,
    creada_por   uuid default auth.uid(),
    creada_at    timestamptz not null default now(),
    tomada_at    timestamptz,
    terminada_at timestamptz
);

alter table public.postulaciones add column if not exists id_postulante text;
create unique index if not exists ux_post_id on public.postulaciones(aviso_id, id_postulante);
create index if not exists ix_post_doc  on public.postulaciones(aviso_id, documento);
create index if not exists ix_post_mail on public.postulaciones(aviso_id, email);
create index if not exists ix_cvs_doc   on public.cvs(aviso_id, documento);
create index if not exists ix_cvs_mail  on public.cvs(aviso_id, email);
create index if not exists ix_runs_aviso on public.scrape_runs(aviso_id, inicio desc);
create index if not exists ix_solicitudes_pend on public.solicitudes(estado, creada_at);

create or replace view public.v_postulaciones
with (security_invoker = true) as             -- respeta el RLS de las tablas
select p.*,
       c.archivo         as cv_archivo,
       c.drive_url       as cv_url,
       c.estado          as cv_estado,
       c.id_postulacion  as bumeran_id_postulacion
from public.postulaciones p
left join public.cvs c
  on c.aviso_id = p.aviso_id
 and ( (p.documento <> '' and c.documento = p.documento)
    or (p.email <> '' and lower(c.email) = p.email) );

-- ------------------------------------------------------------------ seguridad (RLS)
alter table public.avisos        enable row level security;
alter table public.postulaciones enable row level security;
alter table public.cvs           enable row level security;
alter table public.scrape_runs   enable row level security;
alter table public.solicitudes   enable row level security;

drop policy if exists "leer avisos" on public.avisos;
create policy "leer avisos" on public.avisos for select to authenticated using (true);
drop policy if exists "leer postulaciones" on public.postulaciones;
create policy "leer postulaciones" on public.postulaciones for select to authenticated using (true);
drop policy if exists "leer cvs" on public.cvs;
create policy "leer cvs" on public.cvs for select to authenticated using (true);
drop policy if exists "leer corridas" on public.scrape_runs;
create policy "leer corridas" on public.scrape_runs for select to authenticated using (true);
drop policy if exists "leer solicitudes" on public.solicitudes;
create policy "leer solicitudes" on public.solicitudes for select to authenticated using (true);
drop policy if exists "pedir actualizacion" on public.solicitudes;
create policy "pedir actualizacion" on public.solicitudes for insert to authenticated
    with check (estado = 'pendiente');

-- ------------------------------------------------------------------ ranking por embeddings (e5)
-- El scraper calcula el ranking en segundo plano al bajar el CSV (aviso nuevo o postulantes nuevos) y la web
-- solo lo lee. criterios = requisitos de la oferta (scraping/criterios.py), con pesos iguales.
alter table public.avisos add column if not exists criterios jsonb;
alter table public.avisos add column if not exists criterios_version text;
alter table public.avisos add column if not exists ranking_at timestamptz;

create table if not exists public.ranking_embeddings (
    aviso_id          text not null,
    clave             text not null,
    id_postulante     text,
    criterios_version text not null,
    backend           text not null,            -- e5 | tfidf
    ranking           integer,
    score             double precision,         -- e5: reescalado 0-1 dentro del aviso (el mejor = 1)
    score_bruto       double precision,         -- similitud original del modelo
    req_sims          jsonb,                    -- similitud por criterio (misma escala que score)
    req_sims_bruto    jsonb,
    req_fragmentos    jsonb,                    -- fragmento del CV que respalda cada criterio
    explicacion       text,
    explicacion_bruta text,
    calculado_at      timestamptz,
    primary key (aviso_id, clave),
    foreign key (aviso_id, clave) references public.postulaciones(aviso_id, clave) on delete cascade
);

alter table public.ranking_embeddings enable row level security;
drop policy if exists "leer ranking" on public.ranking_embeddings;
create policy "leer ranking" on public.ranking_embeddings for select to authenticated using (true);

-- ---------------------------------------------------------------------------------------------------------------
-- Base centralizada (web: «Base centralizada»): todos los postulantes de todos los avisos, solo con los campos que
-- muestra y filtra la página (sin edad, género, estado civil ni nacionalidad). persona_id agrupa las postulaciones
-- de una misma persona (misma clave en distintos avisos) sin exponer el documento.
-- ---------------------------------------------------------------------------------------------------------------
create or replace view public.v_base_postulantes
with (security_invoker = true) as             -- respeta el RLS de las tablas (solo usuarios con sesión)
select md5(p.clave)                                          as persona_id,
       p.aviso_id,
       a.titulo                                              as aviso_titulo,
       a.detalle_json -> 'migas' ->> 1                       as aviso_area,
       p.id_postulante,
       initcap(trim(p.nombre))                               as nombre,
       initcap(trim(p.apellido))                             as apellido,
       nullif(p.email, '')                                   as email,
       nullif(p.datos_json ->> 'Teléfono celular', '')       as telefono,
       nullif(p.datos_json ->> 'Fecha Postulación', '')      as fecha_postulacion,
       coalesce(nullif(p.datos_json ->> 'Ciudad', ''), nullif(p.datos_json ->> 'Lugar de residencia', '')) as ciudad,
       nullif(p.datos_json ->> 'Exp[1] Puesto', '')          as puesto_actual,
       nullif(p.datos_json ->> 'Exp[1] Empresa', '')         as empresa_actual,
       nullif(p.datos_json ->> 'Exp[1] Area', '')            as area_experiencia,
       est.titulo                                            as estudio,        -- el de mayor nivel, no el último
       est.nivel                                             as nivel_estudio,
       est.estado                                            as estado_estudio,
       est.institucion                                       as institucion,
       nullif(p.datos_json ->> 'Idiomas', '')                as idiomas,
       (select c.drive_url from public.cvs c
         where c.aviso_id = p.aviso_id and c.drive_url is not null
           and ((p.documento <> '' and c.documento = p.documento) or (p.email <> '' and lower(c.email) = p.email))
         limit 1)                                            as cv_url,
       exists (select 1 from public.cvs c
         where c.aviso_id = p.aviso_id and c.estado = 'sin_adjunto'
           and ((p.documento <> '' and c.documento = p.documento) or (p.email <> '' and lower(c.email) = p.email))) as sin_cv
from public.postulaciones p
join public.avisos a on a.aviso_id = p.aviso_id
left join lateral (
  select e.value as nivel,
         nullif(p.datos_json ->> replace(e.key, 'Nivel', 'Titulo'), '')      as titulo,
         nullif(p.datos_json ->> replace(e.key, 'Nivel', 'Estado'), '')      as estado,
         nullif(p.datos_json ->> replace(e.key, 'Nivel', 'Institucion'), '') as institucion
  from jsonb_each_text(p.datos_json) e
  where e.key like 'Est[%] Nivel' and e.value <> ''
  order by case e.value when 'Doctorado' then 7 when 'Master' then 6 when 'Posgrado' then 5 when 'Universitario' then 4
                        when 'Terciario/Técnico' then 3 when 'Secundario' then 2 else 1 end desc, e.key
  limit 1) est on true
where p.en_ultimo_csv = 1;

grant select on public.v_base_postulantes to authenticated;

-- Postulantes marcados «En revisión» desde la web (ranking). Se comparte entre todo el equipo de GTH:
-- quien entra desde otra PC ve las mismas marcas. La clave es el aviso de Bumeran + id del postulante.
create table if not exists public.en_revision (
    aviso_id          text not null,
    id_postulante     text not null,
    marcado_por       uuid default auth.uid(),
    marcado_por_email text default (auth.jwt() ->> 'email'),
    marcado_at        timestamptz not null default now(),
    primary key (aviso_id, id_postulante)
);
alter table public.en_revision enable row level security;
drop policy if exists "leer en revision" on public.en_revision;
create policy "leer en revision" on public.en_revision for select to authenticated using (true);
drop policy if exists "marcar en revision" on public.en_revision;
create policy "marcar en revision" on public.en_revision for insert to authenticated with check (true);
drop policy if exists "desmarcar en revision" on public.en_revision;
create policy "desmarcar en revision" on public.en_revision for delete to authenticated using (true);
grant select, insert, delete on public.en_revision to authenticated;


-- >>> supabase/migrations/20261015230000_comentarios_internos.sql
-- Aplicar solo en GTH_Bumeran. No modifica postulaciones, CVs ni rankings.
-- El administrador debe dar acceso explícito a cada colaborador antes de usar comentarios:
-- insert into public.gth_colaboradores (user_id)
-- select id from auth.users where email in ('correo-del-colaborador');
create table public.gth_colaboradores (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.gth_colaboradores enable row level security;
revoke all on public.gth_colaboradores from anon, authenticated;
grant select on public.gth_colaboradores to authenticated;
create policy colaboradores_ver_acceso on public.gth_colaboradores
  for select to authenticated using (user_id = (select auth.uid()));

create table public.comentarios_internos (
  aviso_id text not null check (length(aviso_id) between 1 and 250),
  id_postulante text not null check (length(id_postulante) between 1 and 250),
  texto text not null check (length(btrim(texto)) between 1 and 4000),
  actualizado_at timestamptz not null default now(),
  actualizado_por uuid references auth.users(id) on delete set null default auth.uid(),
  primary key (aviso_id, id_postulante)
);
alter table public.comentarios_internos enable row level security;
revoke all on public.comentarios_internos from anon, authenticated;
grant select, insert, update, delete on public.comentarios_internos to authenticated;

create policy comentarios_lectura on public.comentarios_internos for select to authenticated
  using (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));
create policy comentarios_creacion on public.comentarios_internos for insert to authenticated
  with check (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));
create policy comentarios_edicion on public.comentarios_internos for update to authenticated
  using (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())))
  with check (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));
create policy comentarios_borrado on public.comentarios_internos for delete to authenticated
  using (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));

create function public.sellar_comentario_interno() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.actualizado_at := now();
  new.actualizado_por := auth.uid();
  return new;
end;
$$;
revoke execute on function public.sellar_comentario_interno() from public, anon;
grant execute on function public.sellar_comentario_interno() to authenticated;
create trigger sellar_comentario before insert or update on public.comentarios_internos
  for each row execute function public.sellar_comentario_interno();


-- >>> supabase/migrations/20261016001000_avance_compartido.sql
-- Ejecutar en GTH_Bumeran después de comentarios_internos. Reutiliza gth_colaboradores.
-- No cambia las tablas del scraper ni los rankings.
begin;
create table public.gth_avance (
  aviso_id text not null check (length(aviso_id) between 1 and 250),
  id_postulante text not null check (length(id_postulante) between 1 and 250),
  etapa text not null check (etapa in ('postulado','preseleccionado','en_entrevista','contratado','no_continua')),
  actualizado_at timestamptz not null default now(),
  primary key (aviso_id,id_postulante)
);
create table public.gth_acciones (
  aviso_id text not null,
  id_postulante text not null,
  accion text not null check (accion in ('multitest','agradecimiento','entrevista')),
  estado text not null default 'preparado' check (estado in ('preparado','confirmado')),
  detalle jsonb not null check (octet_length(detalle::text) <= 16000),
  creado_por uuid not null default auth.uid() references auth.users(id),
  creado_at timestamptz not null default now(),
  confirmado_at timestamptz,
  primary key (aviso_id,id_postulante,accion),
  foreign key (aviso_id,id_postulante) references public.gth_avance
);
alter table public.gth_avance enable row level security;
alter table public.gth_acciones enable row level security;
revoke all on public.gth_avance, public.gth_acciones from anon, authenticated;
grant select, insert, update on public.gth_avance to authenticated;
grant select, insert, update, delete on public.gth_acciones to authenticated;
create policy avance_equipo on public.gth_avance for all to authenticated
 using (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())))
 with check (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));
create policy acciones_equipo_lectura on public.gth_acciones for select to authenticated
 using (exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));
create policy acciones_equipo_insertar on public.gth_acciones for insert to authenticated
 with check (creado_por = (select auth.uid()) and estado = 'preparado' and exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));
create policy acciones_equipo_confirmar on public.gth_acciones for update to authenticated
 using (creado_por = (select auth.uid()) and estado = 'preparado' and exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())))
 with check (creado_por = (select auth.uid()) and estado = 'confirmado' and exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));
create policy acciones_equipo_liberar on public.gth_acciones for delete to authenticated
 using (creado_por = (select auth.uid()) and estado = 'preparado' and exists (select 1 from public.gth_colaboradores where user_id = (select auth.uid())));

create function public.gth_iniciar_avance(p_aviso text,p_filas jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.gth_avance(aviso_id,id_postulante,etapa)
  select p_aviso,x.id_postulante,x.etapa from jsonb_to_recordset(p_filas) as x(id_postulante text,etapa text)
  order by x.id_postulante on conflict do nothing;
end; $$;

create function public.gth_mover_etapas(p_aviso text,p_cambios jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
declare x record; actual text; etapas text[] := array['postulado','preseleccionado','en_entrevista','contratado'];
begin
  if jsonb_array_length(p_cambios) = 0 then raise exception 'Seleccion vacia'; end if;
  for x in select * from jsonb_to_recordset(p_cambios) as r(id_postulante text,anterior text,nueva text) order by id_postulante loop
    select etapa into actual from public.gth_avance where aviso_id=p_aviso and id_postulante=x.id_postulante for update;
    if actual is null or actual <> x.anterior or actual in ('contratado','no_continua') then raise exception 'El expediente cambio'; end if;
    if exists(select 1 from public.gth_acciones where aviso_id=p_aviso and id_postulante=x.id_postulante and estado='preparado') then raise exception 'Comunicacion pendiente'; end if;
    if x.nueva <> 'no_continua' and (array_position(etapas,x.nueva) is null or abs(array_position(etapas,x.nueva)-array_position(etapas,actual)) <> 1) then raise exception 'Etapa invalida'; end if;
    update public.gth_avance set etapa=x.nueva,actualizado_at=now() where aviso_id=p_aviso and id_postulante=x.id_postulante;
  end loop;
end; $$;

create function public.gth_preparar_accion(p_aviso text,p_accion text,p_destinatarios jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
declare x record; actual text;
begin
  if jsonb_array_length(p_destinatarios) = 0 then raise exception 'Seleccion vacia'; end if;
  for x in select * from jsonb_to_recordset(p_destinatarios) as r(id_postulante text,detalle jsonb) order by id_postulante loop
    select etapa into actual from public.gth_avance where aviso_id=p_aviso and id_postulante=x.id_postulante for update;
    if actual is null or not ((p_accion='multitest' and actual='preseleccionado') or (p_accion='entrevista' and actual='en_entrevista') or (p_accion='agradecimiento' and actual in ('postulado','no_continua'))) then raise exception 'Etapa incompatible'; end if;
    if exists(select 1 from public.gth_acciones where aviso_id=p_aviso and id_postulante=x.id_postulante and estado='preparado') then raise exception 'Comunicacion pendiente'; end if;
    insert into public.gth_acciones(aviso_id,id_postulante,accion,detalle) values(p_aviso,x.id_postulante,p_accion,x.detalle);
  end loop;
end; $$;

create function public.gth_finalizar_accion(p_aviso text,p_accion text,p_ids text[],p_cancelar boolean default false) returns void
language plpgsql security invoker set search_path = '' as $$
declare persona text; afectadas integer;
begin
  if cardinality(p_ids)=0 then raise exception 'Seleccion vacia'; end if;
  for persona in select unnest(p_ids) order by 1 loop
    perform 1 from public.gth_avance where aviso_id=p_aviso and id_postulante=persona for update;
    if p_cancelar then
      delete from public.gth_acciones where aviso_id=p_aviso and id_postulante=persona and accion=p_accion and estado='preparado' and creado_por=auth.uid();
    else
      update public.gth_acciones set estado='confirmado',confirmado_at=now() where aviso_id=p_aviso and id_postulante=persona and accion=p_accion and estado='preparado' and creado_por=auth.uid();
    end if;
    get diagnostics afectadas = row_count;
    if afectadas<>1 then raise exception 'Accion ajena o ya finalizada'; end if;
    if not p_cancelar and p_accion='agradecimiento' then
      update public.gth_avance set etapa='no_continua',actualizado_at=now() where aviso_id=p_aviso and id_postulante=persona and etapa='postulado';
    end if;
  end loop;
end; $$;
revoke execute on function public.gth_iniciar_avance(text,jsonb),public.gth_mover_etapas(text,jsonb),public.gth_preparar_accion(text,text,jsonb),public.gth_finalizar_accion(text,text,text[],boolean) from public,anon;
grant execute on function public.gth_iniciar_avance(text,jsonb),public.gth_mover_etapas(text,jsonb),public.gth_preparar_accion(text,text,jsonb),public.gth_finalizar_accion(text,text,text[],boolean) to authenticated;
commit;


-- >>> supabase/migrations/20261016004500_retroceso_desde_contratado.sql
-- Ejecutar en GTH_Bumeran después de avance_compartido.
-- Permite corregir Contratado → En entrevista; conserva comunicaciones y permisos.
begin;
create or replace function public.gth_mover_etapas(p_aviso text,p_cambios jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
declare x record; actual text; etapas text[] := array['postulado','preseleccionado','en_entrevista','contratado'];
begin
  if jsonb_array_length(p_cambios) = 0 then raise exception 'Seleccion vacia'; end if;
  for x in select * from jsonb_to_recordset(p_cambios) as r(id_postulante text,anterior text,nueva text) order by id_postulante loop
    select etapa into actual from public.gth_avance where aviso_id=p_aviso and id_postulante=x.id_postulante for update;
    if actual is null or actual <> x.anterior or (actual = 'no_continua' or (actual = 'contratado' and x.nueva is distinct from 'en_entrevista')) then raise exception 'El expediente cambio'; end if;
    if exists(select 1 from public.gth_acciones where aviso_id=p_aviso and id_postulante=x.id_postulante and estado='preparado') then raise exception 'Comunicacion pendiente'; end if;
    if x.nueva <> 'no_continua' and (array_position(etapas,x.nueva) is null or abs(array_position(etapas,x.nueva)-array_position(etapas,actual)) <> 1) then raise exception 'Etapa invalida'; end if;
    update public.gth_avance set etapa=x.nueva,actualizado_at=now() where aviso_id=p_aviso and id_postulante=x.id_postulante;
  end loop;
end; $$;

revoke execute on function public.gth_mover_etapas(text,jsonb) from public, anon;
grant execute on function public.gth_mover_etapas(text,jsonb) to authenticated;
commit;


-- >>> supabase/migrations/20261017120000_niveles_acceso.sql
-- Niveles de acceso de GTH. Aplicar en GTH_Bumeran después de avance_compartido.
--   * maestro: ve todos los avisos (también los confidenciales) y administra usuarios y permisos.
--   * general: ve los avisos no confidenciales; si su perfil trae una lista de avisos, solo esos.
-- Las cuentas se crean desde la web (api/usuarios.ts, con la clave service_role del servidor).
-- El scraper entra con el rol postgres y no pasa por RLS: sigue leyendo y escribiendo todo.
begin;

create table public.gth_perfiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  nombre text not null default '' check (length(nombre) <= 120),
  nivel text not null default 'general' check (nivel in ('maestro','general')),
  secciones text[],                      -- null = todas las secciones del menú
  avisos text[],                         -- null = todos los avisos no confidenciales
  debe_cambiar_clave boolean not null default true,
  activo boolean not null default true,
  actualizado_at timestamptz not null default now()
);

create table public.avisos_confidenciales (
  aviso_id text primary key check (length(aviso_id) between 1 and 250),
  marcado_por uuid references auth.users(id) on delete set null default auth.uid(),
  marcado_at timestamptz not null default now()
);

-- security definer: las políticas las llaman sin depender del RLS de estas tablas.
create function public.gth_es_maestro() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.gth_perfiles
                 where user_id = (select auth.uid()) and activo and nivel = 'maestro');
$$;

create function public.gth_puede_ver_aviso(p_aviso text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.gth_perfiles p
    where p.user_id = (select auth.uid()) and p.activo
      and (p.nivel = 'maestro'
           or (not exists (select 1 from public.avisos_confidenciales c where c.aviso_id = p_aviso)
               and (p.avisos is null or p_aviso = any (p.avisos)))));
$$;

-- El propio usuario apaga el aviso de contraseña temporal después de cambiarla.
create function public.gth_clave_cambiada() returns void
language sql security definer set search_path = '' as $$
  update public.gth_perfiles set debe_cambiar_clave = false, actualizado_at = now()
  where user_id = (select auth.uid());
$$;

revoke execute on function public.gth_es_maestro(), public.gth_puede_ver_aviso(text), public.gth_clave_cambiada() from public, anon;
grant execute on function public.gth_es_maestro(), public.gth_puede_ver_aviso(text), public.gth_clave_cambiada() to authenticated;

alter table public.gth_perfiles enable row level security;
alter table public.avisos_confidenciales enable row level security;
revoke all on public.gth_perfiles, public.avisos_confidenciales from anon, authenticated;
grant select, update on public.gth_perfiles to authenticated;
grant select, insert, delete on public.avisos_confidenciales to authenticated;

create policy perfiles_lectura on public.gth_perfiles for select to authenticated
  using (user_id = (select auth.uid()) or public.gth_es_maestro());
create policy perfiles_edicion on public.gth_perfiles for update to authenticated
  using (public.gth_es_maestro()) with check (public.gth_es_maestro());
create policy confidenciales_lectura on public.avisos_confidenciales for select to authenticated
  using (public.gth_es_maestro());
create policy confidenciales_marcar on public.avisos_confidenciales for insert to authenticated
  with check (public.gth_es_maestro());
create policy confidenciales_desmarcar on public.avisos_confidenciales for delete to authenticated
  using (public.gth_es_maestro());

-- Un maestro no puede quitarse a sí mismo el nivel ni desactivarse (evita quedarse sin administradores).
create function public.gth_proteger_perfil() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if old.user_id = auth.uid() and (new.nivel <> old.nivel or new.activo <> old.activo) then
    raise exception 'No puedes cambiar tu propio nivel ni desactivar tu cuenta';
  end if;
  if new.user_id <> old.user_id or new.email <> old.email then raise exception 'Campo no editable'; end if;
  new.actualizado_at := now();
  return new;
end; $$;
create trigger proteger_perfil before update on public.gth_perfiles
  for each row execute function public.gth_proteger_perfil();

-- Políticas restrictivas: se suman (AND) a las que ya tiene cada tabla, sin reemplazarlas.
create policy aviso_visible on public.avisos as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.postulaciones as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.cvs as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.ranking_embeddings as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.en_revision as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.comentarios_internos as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.gth_avance as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.gth_acciones as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.scrape_runs as restrictive for all to authenticated
  using (aviso_id is null or public.gth_puede_ver_aviso(aviso_id));
create policy aviso_visible on public.solicitudes as restrictive for all to authenticated
  using (aviso_id is null or public.gth_puede_ver_aviso(aviso_id))
  with check (aviso_id is null or public.gth_puede_ver_aviso(aviso_id));

-- Los usuarios que ya existían quedan como maestros para no perder el acceso al aplicar la migración.
insert into public.gth_perfiles (user_id, email, nivel, debe_cambiar_clave)
select id, email, 'maestro', false from auth.users
on conflict do nothing;

commit;


-- >>> supabase/migrations/20261018023948_historial_recurrencia_base_paginada.sql
-- Historial y recurrencia sobre todas las postulaciones guardadas, no solo el último CSV.
-- Todas las vistas y funciones consultan como el usuario: también los conteos respetan RLS.
create function public.gth_documento(text) returns text
language sql immutable parallel safe security invoker set search_path = '' as $$
  select nullif(regexp_replace(upper(trim($1)), '[^A-Z0-9]', '', 'g'), '');
$$;

create function public.gth_fecha(text) returns date
language plpgsql immutable parallel safe security invoker set search_path = '' as $$
begin
  if $1 ~ '^\d{4}-\d{2}-\d{2}' then return left($1, 10)::date; end if;
  if $1 ~ '^\d{1,2}/\d{1,2}/\d{4}' then
    return make_date(left(split_part($1,'/',3),4)::integer, split_part($1,'/',2)::integer, split_part($1,'/',1)::integer);
  end if;
  return null;
exception when others then return null;
end; $$;

create function public.gth_sin_tildes(text) returns text
language sql immutable parallel safe security invoker set search_path = '' as $$
  select translate(lower(coalesce($1,'')), 'áéíóúüñ', 'aeiouun');
$$;

create function public.gth_nivel_estudio(text) returns integer
language sql immutable parallel safe security invoker set search_path = '' as $$
  select coalesce(array_position(array['Doctorado','Master','Posgrado','Universitario','Terciario/Técnico','Secundario','Curso','Otro'], $1), 9);
$$;

create schema if not exists gth_interno;
revoke all on schema gth_interno from public,anon;
grant usage on schema gth_interno to authenticated;

create view gth_interno.identidades with (security_invoker = true) as
with normalizadas as materialized (
  select p.*, public.gth_documento(p.documento) as doc, nullif(lower(trim(p.email)), '') as mail
  from public.postulaciones p
), correos as (
  select mail, min(doc) as doc, count(distinct doc) as documentos
  from normalizadas where mail is not null group by mail
)
select n.*,
  md5(case
    when n.doc is not null then 'DOC:' || n.doc
    when c.documentos = 1 then 'DOC:' || c.doc
    when n.mail is not null and coalesce(c.documentos,0) = 0 then 'MAIL:' || n.mail
    else 'FILA:' || n.aviso_id || ':' || n.clave
  end) as persona_id
from normalizadas n left join correos c on c.mail = n.mail;

create function public.gth_historial_postulaciones(p_aviso_id text, p_id_postulante text)
returns table(aviso_id text, titulo text, fecha date, score double precision, backend text, criterios_version text)
language sql stable security invoker set search_path = '' as $$
  with persona as (
    select persona_id from gth_interno.identidades
    where aviso_id = p_aviso_id and id_postulante = p_id_postulante
  ), postulaciones as (
    select distinct on (p.aviso_id) p.*
    from gth_interno.identidades p
    where p.persona_id in (select persona_id from persona)
    order by p.aviso_id, public.gth_fecha(p.fecha_postulacion) desc nulls last, p.actualizado_at desc nulls last, p.clave
  )
  select p.aviso_id, a.titulo, public.gth_fecha(p.fecha_postulacion), r.score, r.backend, r.criterios_version
  from postulaciones p join public.avisos a on a.aviso_id = p.aviso_id
  left join lateral (
    select r.score,r.backend,r.criterios_version from public.ranking_embeddings r
    where r.aviso_id = p.aviso_id and r.clave = p.clave
      and (a.criterios_version is null or r.criterios_version = a.criterios_version)
    order by r.calculado_at desc nulls last limit 1
  ) r on true
  order by public.gth_fecha(p.fecha_postulacion) desc nulls last, p.aviso_id;
$$;

create function public.gth_resumen_postulaciones(p_aviso_id text, p_ids text[])
returns table(id_postulante text, total integer)
language sql stable security invoker set search_path = '' as $$
  with identidades as materialized (select persona_id,aviso_id,id_postulante from gth_interno.identidades),
  seleccion as (select distinct id_postulante,persona_id from identidades
    where aviso_id = p_aviso_id and id_postulante = any(p_ids)),
  conteos as (select persona_id, count(distinct aviso_id)::integer as total from identidades
    where persona_id in (select persona_id from seleccion) group by persona_id)
  select s.id_postulante,c.total from seleccion s join conteos c using(persona_id);
$$;

-- La agrupación se hace ANTES de filtrar y paginar, por lo que una persona no queda partida entre páginas.
create view public.v_gth_personas_base with (security_invoker = true) as
with filas as materialized (
  select distinct on (i.persona_id,b.aviso_id) b.*, i.persona_id as identidad,
    coalesce(public.gth_fecha(b.fecha_postulacion),public.gth_fecha(i.fecha_postulacion)) as fecha,
    (select string_agg(case when ord > 1 and lower(palabra) = any(array['de','del','la','las','los','y']) then lower(palabra) else initcap(palabra) end,' ' order by ord) from regexp_split_to_table(regexp_replace(trim(b.ciudad),'[.\s]+$','','g'),'\s+') with ordinality t(palabra,ord)) as ciudad_normalizada
  from public.v_base_postulantes b join gth_interno.identidades i
    on i.aviso_id = b.aviso_id and md5(i.clave) = b.persona_id
  order by i.persona_id,b.aviso_id,i.actualizado_at desc nulls last,i.clave
), grupos as (
  select identidad,
    (jsonb_agg(to_jsonb(f) order by fecha desc nulls last,aviso_id)->0) as reciente,
    (jsonb_agg(to_jsonb(f) order by public.gth_nivel_estudio(nivel_estudio),fecha desc nulls last,aviso_id)->0) as estudios,
    (array_agg(cv_url order by fecha desc nulls last,aviso_id) filter (where cv_url is not null))[1] as cv_url,
    bool_or(sin_cv) as sin_cv,
    jsonb_agg(jsonb_build_object('id',aviso_id,'titulo',coalesce(aviso_titulo,aviso_id),'area',aviso_area,'fecha',fecha)
      order by fecha desc nulls last,aviso_id) as avisos
  from filas f group by identidad
)
select identidad as id,
  coalesce(nullif(trim(concat_ws(' ',reciente->>'nombre',reciente->>'apellido')),''),reciente->>'id_postulante','Postulante') as nombre,
  reciente->>'email' as email, reciente->>'telefono' as telefono, reciente->>'ciudad_normalizada' as ciudad,
  reciente->>'puesto_actual' as puesto, reciente->>'empresa_actual' as empresa, reciente->>'area_experiencia' as "areaExperiencia",
  estudios->>'estudio' as estudio, estudios->>'nivel_estudio' as "nivelEstudio", estudios->>'estado_estudio' as "estadoEstudio", estudios->>'institucion' as institucion,
  coalesce((select jsonb_agg(jsonb_build_object('idioma',trim(split_part(x,' - ',1)), 'nivel',trim(split_part(x,' - ',2))))
    from unnest(string_to_array(reciente->>'idiomas','/')) x where trim(x) <> ''),'[]'::jsonb) as idiomas,
  (reciente->>'fecha')::date as "ultimaPostulacion", avisos,
  jsonb_build_object('estado',case when cv_url is not null then 'disponible' when sin_cv then 'sin_adjunto' else 'pendiente' end,
    'enlace',cv_url,'vista',case when cv_url ~ 'drive.google.com/file/d/[^/]+'
       then 'https://drive.google.com/file/d/' || substring(cv_url from '/file/d/([^/]+)') || '/preview' else null end) as cv
from grupos;

create function public.gth_base_centralizada(p_filtros jsonb default '{}', p_pagina integer default 1,
  p_por_pagina integer default 50, p_incluir_resumen boolean default true)
returns jsonb language sql stable security invoker set search_path = '' as $$
  with personas as materialized (select * from public.v_gth_personas_base),
  filtradas as materialized (
    select p.* from personas p where
      (coalesce(p_filtros->>'texto','') = '' or position(public.gth_sin_tildes(trim(p_filtros->>'texto')) in
        public.gth_sin_tildes(concat_ws(' ',nombre,puesto,empresa,estudio,institucion,"areaExperiencia"))) > 0)
      and (coalesce(p_filtros->>'aviso','') = '' or exists(select 1 from jsonb_array_elements(avisos) a where a->>'id' = p_filtros->>'aviso'))
      and (coalesce(p_filtros->>'area','') = '' or exists(select 1 from jsonb_array_elements(avisos) a where a->>'area' = p_filtros->>'area'))
      and (coalesce(p_filtros->>'nivel','') = '' or public.gth_nivel_estudio("nivelEstudio") <= public.gth_nivel_estudio(p_filtros->>'nivel'))
      and (coalesce(p_filtros->>'estado','') = '' or "estadoEstudio" = p_filtros->>'estado')
      and (coalesce(p_filtros->>'ciudad','') = '' or ciudad = p_filtros->>'ciudad')
      and (coalesce(p_filtros->>'desde','') = '' or "ultimaPostulacion" >= public.gth_fecha(p_filtros->>'desde'))
      and (coalesce(p_filtros->>'cv','') = '' or (p_filtros->>'cv' = 'con' and cv->>'estado' = 'disponible')
        or (p_filtros->>'cv' = 'sin' and cv->>'estado' <> 'disponible'))
      and (coalesce(p_filtros->>'varios','false') <> 'true' or jsonb_array_length(avisos) > 1)
      and (coalesce(p_filtros->>'idioma','') = '' or exists(select 1 from jsonb_array_elements(idiomas) i
        where i->>'idioma' = p_filtros->>'idioma' and (coalesce(p_filtros->>'nivelIdioma','') = ''
          or array_position(array['Básico','Intermedio','Avanzado','Nativo'],i->>'nivel') >=
             array_position(array['Básico','Intermedio','Avanzado','Nativo'],p_filtros->>'nivelIdioma'))))
  ), pagina as (
    select * from filtradas order by "ultimaPostulacion" desc nulls last,nombre,id
    limit least(greatest(p_por_pagina,1),500) offset ((greatest(p_pagina,1)::bigint-1)*least(greatest(p_por_pagina,1),500))
  )
  select jsonb_build_object('personas',coalesce((select jsonb_agg(to_jsonb(p)) from pagina p),'[]'::jsonb),
    'total',(select count(*) from filtradas),
    'resumen',case when p_incluir_resumen then (select jsonb_build_object('personas',count(*),
      'postulaciones',coalesce(sum(jsonb_array_length(avisos)),0),
      'recurrentes',count(*) filter(where jsonb_array_length(avisos)>1)) from personas) end,
    'opciones',case when p_incluir_resumen then jsonb_build_object(
      'avisos',coalesce((select jsonb_agg(jsonb_build_array(id,titulo) order by titulo,id)
        from (select distinct a->>'id' as id,a->>'titulo' as titulo from personas,jsonb_array_elements(avisos) a) x),'[]'::jsonb),
      'areas',coalesce((select jsonb_agg(v order by v) from (select distinct a->>'area' as v from personas,jsonb_array_elements(avisos) a where nullif(a->>'area','') is not null) x),'[]'::jsonb),
      'ciudades',coalesce((select jsonb_agg(v order by v) from (select distinct ciudad as v from personas where nullif(ciudad,'') is not null) x),'[]'::jsonb),
      'idiomas',coalesce((select jsonb_agg(v order by v) from (select distinct i->>'idioma' as v from personas,jsonb_array_elements(idiomas) i where nullif(i->>'idioma','') is not null) x),'[]'::jsonb)
    ) end);
$$;

create index if not exists ix_gth_post_documento on public.postulaciones(public.gth_documento(documento)) where documento is not null;
create index if not exists ix_gth_post_correo on public.postulaciones(lower(trim(email))) where email is not null;
create index if not exists ix_gth_post_fecha on public.postulaciones(public.gth_fecha(fecha_postulacion) desc, aviso_id);

revoke all on gth_interno.identidades,public.v_gth_personas_base from public,anon;
-- La identidad con documentos queda en un esquema no expuesto por la Data API.
-- SECURITY INVOKER necesita permisos de las vistas subyacentes; RLS sigue siendo obligatorio.
grant select on gth_interno.identidades,public.v_gth_personas_base to authenticated;
grant select on public.avisos,public.postulaciones,public.cvs,public.ranking_embeddings to authenticated;
revoke execute on function public.gth_documento(text), public.gth_fecha(text), public.gth_sin_tildes(text), public.gth_nivel_estudio(text),
  public.gth_historial_postulaciones(text,text),public.gth_resumen_postulaciones(text,text[]),public.gth_base_centralizada(jsonb,integer,integer,boolean) from public,anon;
grant execute on function public.gth_documento(text), public.gth_fecha(text), public.gth_sin_tildes(text), public.gth_nivel_estudio(text),
  public.gth_historial_postulaciones(text,text),public.gth_resumen_postulaciones(text,text[]),public.gth_base_centralizada(jsonb,integer,integer,boolean) to authenticated;
notify pgrst,'reload schema';


-- >>> supabase/migrations/20261020120000_agradecimiento_preseleccionados.sql
-- «Agradecer a no seleccionados» se envía a quienes rindieron Multitest (Preseleccionado) y no pasaron a Entrevista.
-- Solo cambia qué etapas acepta el agradecimiento; confirmar sigue moviendo a No continúan únicamente a los de Postulado,
-- así que los preseleccionados agradecidos se quedan en su etapa (decisión de GTH, 20/10/2026).
begin;
create or replace function public.gth_preparar_accion(p_aviso text,p_accion text,p_destinatarios jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
declare x record; actual text;
begin
  if jsonb_array_length(p_destinatarios) = 0 then raise exception 'Seleccion vacia'; end if;
  for x in select * from jsonb_to_recordset(p_destinatarios) as r(id_postulante text,detalle jsonb) order by id_postulante loop
    select etapa into actual from public.gth_avance where aviso_id=p_aviso and id_postulante=x.id_postulante for update;
    if actual is null or not ((p_accion='multitest' and actual='preseleccionado') or (p_accion='entrevista' and actual='en_entrevista') or (p_accion='agradecimiento' and actual in ('postulado','no_continua','preseleccionado'))) then raise exception 'Etapa incompatible'; end if;
    if exists(select 1 from public.gth_acciones where aviso_id=p_aviso and id_postulante=x.id_postulante and estado='preparado') then raise exception 'Comunicacion pendiente'; end if;
    insert into public.gth_acciones(aviso_id,id_postulante,accion,detalle) values(p_aviso,x.id_postulante,p_accion,x.detalle);
  end loop;
end; $$;
revoke execute on function public.gth_preparar_accion(text,text,jsonb) from public,anon;
grant execute on function public.gth_preparar_accion(text,text,jsonb) to authenticated;
commit;


-- >>> supabase/migrations/20261020180000_multitest_servidor.sql
-- Envío a Multitest desde la web publicada: la web deja el pedido en multitest_envios y el servidor (la laptop de GTH,
-- python -m scraping.multitest_servidor) lo toma, corre la automatización con Playwright y confirma en gth_acciones a
-- los candidatos agregados. servidor_latido dice si ese servidor está prendido (la web muestra «Servidor apagado»).
begin;
create table if not exists public.multitest_envios (
  id            bigint generated always as identity primary key,
  aviso_id      text not null,
  registros     jsonb not null,                  -- datos del formulario; el servidor los borra al terminar
  estado        text not null default 'pendiente' check (estado in ('pendiente', 'en_curso', 'ok', 'error')),
  resultados    jsonb,                           -- [{ id, ok, error }]
  mensaje       text,
  creado_por    uuid not null default auth.uid(),
  creado_at     timestamptz not null default now(),
  tomado_at     timestamptz,
  terminado_at  timestamptz
);
create index if not exists ix_multitest_envios_pend on public.multitest_envios(estado, creado_at);

create table if not exists public.servidor_latido (
  servicio  text primary key,
  equipo    text,
  visto_at  timestamptz not null default now()
);

alter table public.multitest_envios enable row level security;
alter table public.servidor_latido enable row level security;
-- Solo colaboradores de GTH; cada uno ve y crea sus pedidos de los avisos que puede ver. El servidor usa la
-- conexión directa a la base (sin RLS) para tomarlos y cerrarlos.
create policy multitest_envios_leer on public.multitest_envios for select to authenticated
  using (creado_por = auth.uid() and exists (select 1 from public.gth_colaboradores c where c.user_id = auth.uid()));
create policy multitest_envios_pedir on public.multitest_envios for insert to authenticated
  with check (estado = 'pendiente' and creado_por = auth.uid()
    and exists (select 1 from public.gth_colaboradores c where c.user_id = auth.uid()));
create policy aviso_visible on public.multitest_envios as restrictive for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));
create policy servidor_latido_leer on public.servidor_latido for select to authenticated using (true);

-- Supabase da por defecto todos los permisos a authenticated: aquí solo leer y pedir; cerrar pedidos y marcar el
-- latido lo hace únicamente el servidor.
revoke all on public.multitest_envios, public.servidor_latido from anon, authenticated;
grant select, insert on public.multitest_envios to authenticated;
grant select on public.servidor_latido to authenticated;
commit;


-- >>> supabase/migrations/20261023022909_trayectoria_laboral.sql
-- Aplicar después de niveles_acceso. El scraper escribe; la web consulta y revisa.
begin;

create function public.gth_trayectoria_huella(p_datos jsonb) returns text
language sql immutable parallel safe security invoker set search_path='' as $$
  select md5(coalesce(string_agg(length(key)::text || ':' || key || length(value)::text || ':' || value,
    '' order by key collate "C"),'')) from jsonb_each_text(p_datos)
  where value is not null and key ~ '^Exp\[[0-9]+\] (Empresa|Puesto|Fecha Inicio|Fecha Fin|Descripci[oó]n|Modalidad|Tipo de contrato|Tipo de empleo)$';
$$;

create table public.gth_trayectoria_analisis (
  id uuid primary key default gen_random_uuid(),
  aviso_id text not null,
  clave text not null,
  id_postulante text,
  huella text not null check (huella ~ '^[0-9a-f]{32}$'),
  version text not null,
  estado text not null check (estado in ('patron_detectado','sin_patron','informacion_insuficiente','no_aplica')),
  fecha_referencia date not null,
  vigente_hasta date,
  calculado_at timestamptz not null default now(),
  detalle jsonb not null check (jsonb_typeof(detalle)='object'),
  foreign key(aviso_id,clave) references public.postulaciones(aviso_id,clave) on delete cascade,
  unique(aviso_id,clave,huella,version,fecha_referencia)
);
create index gth_trayectoria_aviso on public.gth_trayectoria_analisis(aviso_id,clave,fecha_referencia desc,calculado_at desc);

create table public.gth_trayectoria_revisiones (
  id uuid primary key default gen_random_uuid(),
  analisis_id uuid not null references public.gth_trayectoria_analisis(id) on delete cascade,
  autor uuid default auth.uid() references auth.users(id) on delete set null,
  estado text not null check (estado in ('justificado','dato_incorrecto','revisado')),
  texto text not null check (length(trim(texto)) between 5 and 2000),
  creada_at timestamptz not null default clock_timestamp()
);
create index gth_trayectoria_revision on public.gth_trayectoria_revisiones(analisis_id,creada_at desc,id);

alter table public.gth_trayectoria_analisis enable row level security;
alter table public.gth_trayectoria_revisiones enable row level security;
revoke all on public.gth_trayectoria_analisis,public.gth_trayectoria_revisiones from public,anon,authenticated;
grant select on public.gth_trayectoria_analisis,public.gth_trayectoria_revisiones to authenticated;
grant insert(analisis_id,estado,texto) on public.gth_trayectoria_revisiones to authenticated;

create policy trayectoria_lectura on public.gth_trayectoria_analisis for select to authenticated
  using (public.gth_puede_ver_aviso(aviso_id));
create policy trayectoria_revision_lectura on public.gth_trayectoria_revisiones for select to authenticated
  using (exists(select 1 from public.gth_trayectoria_analisis a where a.id=analisis_id));
create policy trayectoria_revision_insertar on public.gth_trayectoria_revisiones for insert to authenticated
  with check (autor=(select auth.uid()) and exists (
    select 1 from public.gth_trayectoria_analisis a join public.postulaciones p
      on p.aviso_id=a.aviso_id and p.clave=a.clave
    where a.id=analisis_id and a.version='trayectoria-v1'
      and a.huella=public.gth_trayectoria_huella(p.datos_json)
      and p.en_ultimo_csv=1 and (a.vigente_hasta is null or a.vigente_hasta>=current_date)
      and not exists(select 1 from public.gth_trayectoria_analisis nueva
        where nueva.aviso_id=a.aviso_id and nueva.clave=a.clave and nueva.version=a.version
          and nueva.huella=a.huella and (nueva.fecha_referencia,nueva.calculado_at,nueva.id)>(a.fecha_referencia,a.calculado_at,a.id))));

-- Resumen paginado, sin cronologías completas y sin una llamada por candidato.
create function public.gth_trayectoria_resumen(p_aviso text,p_desde integer default 0)
returns table(id_postulante text,analisis_id uuid,estado text,calculado_at timestamptz,revision text)
language sql stable security invoker set search_path='' as $$
  select p.id_postulante,a.id,
    case when a.id is null then 'pendiente'
      when a.huella<>public.gth_trayectoria_huella(p.datos_json) or a.version<>'trayectoria-v1'
        or a.vigente_hasta<current_date then 'desactualizado' else a.estado end,
    a.calculado_at,
    (select r.estado from public.gth_trayectoria_revisiones r where r.analisis_id=a.id order by r.creada_at desc,r.id desc limit 1)
  from public.postulaciones p
  left join lateral (select a.* from public.gth_trayectoria_analisis a
    where a.aviso_id=p.aviso_id and a.clave=p.clave
    order by (a.huella=public.gth_trayectoria_huella(p.datos_json) and a.version='trayectoria-v1') desc,
      a.fecha_referencia desc,a.calculado_at desc,a.id desc limit 1) a on true
  where p.aviso_id=p_aviso and p.en_ultimo_csv=1 and p.id_postulante is not null
  order by p.id_postulante,p.clave offset greatest(0,p_desde) limit 500;
$$;

revoke execute on function public.gth_trayectoria_huella(jsonb),public.gth_trayectoria_resumen(text,integer) from public,anon;
grant execute on function public.gth_trayectoria_huella(jsonb),public.gth_trayectoria_resumen(text,integer) to authenticated;
notify pgrst,'reload schema';
commit;


-- >>> supabase/migrations/20261023041107_trayectoria_fechas_v2.sql
-- Aplicar después de trayectoria_laboral. No borra análisis ni revisiones anteriores.
-- v1 queda como historial; ejecutar --solo-trayectoria con el scraper actualizado para generar v2.
begin;

alter policy trayectoria_revision_insertar on public.gth_trayectoria_revisiones to authenticated
  with check (autor=(select auth.uid()) and exists (
    select 1 from public.gth_trayectoria_analisis a join public.postulaciones p
      on p.aviso_id=a.aviso_id and p.clave=a.clave
    where a.id=analisis_id and a.version='trayectoria-v2'
      and a.huella=public.gth_trayectoria_huella(p.datos_json)
      and p.en_ultimo_csv=1 and (a.vigente_hasta is null or a.vigente_hasta>=current_date)
      and not exists(select 1 from public.gth_trayectoria_analisis nueva
        where nueva.aviso_id=a.aviso_id and nueva.clave=a.clave and nueva.version=a.version
          and nueva.huella=a.huella and (nueva.fecha_referencia,nueva.calculado_at,nueva.id)>(a.fecha_referencia,a.calculado_at,a.id))));


create or replace function public.gth_trayectoria_resumen(p_aviso text,p_desde integer default 0)
returns table(id_postulante text,analisis_id uuid,estado text,calculado_at timestamptz,revision text)
language sql stable security invoker set search_path='' as $$
  select p.id_postulante,a.id,
    case when a.id is null then 'pendiente'
      when a.huella<>public.gth_trayectoria_huella(p.datos_json) or a.version<>'trayectoria-v2'
        or a.vigente_hasta<current_date then 'desactualizado' else a.estado end,
    a.calculado_at,
    (select r.estado from public.gth_trayectoria_revisiones r where r.analisis_id=a.id order by r.creada_at desc,r.id desc limit 1)
  from public.postulaciones p
  left join lateral (select a.* from public.gth_trayectoria_analisis a
    where a.aviso_id=p.aviso_id and a.clave=p.clave
    order by (a.huella=public.gth_trayectoria_huella(p.datos_json) and a.version='trayectoria-v2') desc,
      a.fecha_referencia desc,a.calculado_at desc,a.id desc limit 1) a on true
  where p.aviso_id=p_aviso and p.en_ultimo_csv=1 and p.id_postulante is not null
  order by p.id_postulante,p.clave offset greatest(0,p_desde) limit 500;
$$;

revoke execute on function public.gth_trayectoria_resumen(text,integer) from public,anon;
grant execute on function public.gth_trayectoria_resumen(text,integer) to authenticated;
notify pgrst,'reload schema';
commit;


-- >>> supabase/migrations/20261023153232_superadministracion_y_sueldos.sql
-- Integra la entrega de sueldos sobre ETAPA-I sin sustituir el proyecto por el ZIP antiguo.
-- No identifica a Andrea por nombre ni promueve automáticamente a usuarios existentes.
begin;

alter table public.gth_perfiles drop constraint gth_perfiles_nivel_check;
alter table public.gth_perfiles add constraint gth_perfiles_nivel_check
  check (nivel in ('superadmin', 'maestro', 'general'));

create schema if not exists gth_privado;
revoke all on schema gth_privado from public, anon;
grant usage on schema gth_privado to authenticated;
create function gth_privado.es_superadmin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.gth_perfiles
    where user_id = (select auth.uid()) and activo and nivel = 'superadmin');
$$;
revoke all on function gth_privado.es_superadmin() from public, anon;
grant execute on function gth_privado.es_superadmin() to authenticated;

-- Conserva las políticas anteriores: ambos niveles administrativos ven todos los avisos.
create or replace function public.gth_es_maestro() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.gth_perfiles
    where user_id = (select auth.uid()) and activo and nivel in ('superadmin','maestro'));
$$;
create or replace function public.gth_puede_ver_aviso(p_aviso text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.gth_perfiles p
    where p.user_id = (select auth.uid()) and p.activo
      and (p.nivel in ('superadmin','maestro')
        or (not exists (select 1 from public.avisos_confidenciales c where c.aviso_id = p_aviso)
          and (p.avisos is null or p_aviso = any (p.avisos)))));
$$;

-- También protege las actualizaciones directas a PostgREST, fuera de la interfaz.
create or replace function public.gth_proteger_perfil() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.user_id <> old.user_id or new.email <> old.email then raise exception 'Campo no editable'; end if;
  if auth.uid() is not null then
    if old.user_id = auth.uid() and (new.nivel <> old.nivel or new.activo <> old.activo) then
      raise exception 'No puedes cambiar tu propio nivel ni desactivar tu cuenta';
    end if;
    if old.nivel = 'superadmin' and (old.user_id <> auth.uid() or new.nivel <> old.nivel or new.activo <> old.activo) then
      raise exception 'La cuenta superadministradora está protegida';
    end if;
    if new.nivel = 'superadmin' and old.nivel <> 'superadmin' then
      raise exception 'El alta de superadministración requiere configuración del responsable de la base';
    end if;
    if old.user_id <> auth.uid() and not gth_privado.es_superadmin() and (old.nivel <> 'general' or new.nivel <> 'general') then
      raise exception 'Solo la superadministradora puede gestionar administradores';
    end if;
  end if;
  new.actualizado_at := now();
  return new;
end; $$;

-- Oferta compartida por aviso. Una fila con monto null representa una oferta retirada.
-- No tiene FK a avisos: también admite los códigos de convocatorias creadas manualmente.
create table public.gth_sueldos_ofertados (
  aviso_id text primary key check (length(aviso_id) between 1 and 250),
  monto numeric(12,2) check (monto is null or (monto > 0 and monto <= 1000000)),
  actualizado_por uuid references auth.users(id) on delete set null default auth.uid(),
  actualizado_at timestamptz not null default now()
);
alter table public.gth_sueldos_ofertados enable row level security;
revoke all on public.gth_sueldos_ofertados from public, anon, authenticated;
grant select, insert, update on public.gth_sueldos_ofertados to authenticated;
grant all on public.gth_sueldos_ofertados to service_role;
create policy sueldos_lectura on public.gth_sueldos_ofertados for select to authenticated
  using (public.gth_puede_ver_aviso(aviso_id));
create policy sueldos_alta on public.gth_sueldos_ofertados for insert to authenticated
  with check (gth_privado.es_superadmin() and public.gth_puede_ver_aviso(aviso_id));
create policy sueldos_edicion on public.gth_sueldos_ofertados for update to authenticated
  using (gth_privado.es_superadmin() and public.gth_puede_ver_aviso(aviso_id))
  with check (gth_privado.es_superadmin() and public.gth_puede_ver_aviso(aviso_id));
create function gth_privado.sello_oferta() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if TG_OP = 'UPDATE' and new.aviso_id <> old.aviso_id then raise exception 'El aviso no es editable'; end if;
  new.actualizado_por := auth.uid(); new.actualizado_at := now();
  return new;
end; $$;
revoke all on function gth_privado.sello_oferta() from public, anon;
create trigger sello_oferta before insert or update on public.gth_sueldos_ofertados
  for each row execute function gth_privado.sello_oferta();

commit;


-- >>> supabase/migrations/20261023194032_trayectoria_deteccion_v3.sql
-- Aplicar después de trayectoria_fechas_v2. Conserva snapshots y revisiones anteriores.
-- Actualizar el scraper y ejecutar --solo-trayectoria para generar trayectoria-v3.
begin;

create or replace function public.gth_trayectoria_campo_valido(p_nombre text) returns boolean
language sql immutable parallel safe security invoker set search_path='' as $$
  select btrim(regexp_replace(translate(normalize(p_nombre, NFC),
    'ÁÉÍÓÚÜÑáéíóúüñABCDEFGHIJKLMNOPQRSTUVWXYZ', 'AEIOUUNaeiouunabcdefghijklmnopqrstuvwxyz'),
    U&'[ \0009\000A\000D\000C\000B\00A0\202F\FEFF]+', ' ', 'g'))
    ~ '^exp *\[ *[0-9]+ *\] +(empresa|puesto|descripcion|modalidad|tipo de contrato|tipo de empleo|fecha (de )?(inicio|ingreso|fin|termino|finalizacion|egreso))$';
$$;

create or replace function public.gth_trayectoria_huella(p_datos jsonb) returns text
language sql immutable parallel safe security invoker set search_path='' as $$
  select md5(coalesce(string_agg(length(key)::text || ':' || key || length(value)::text || ':' || value,
    '' order by key collate "C"),'')) from jsonb_each_text(p_datos)
  where value is not null and public.gth_trayectoria_campo_valido(key);
$$;

alter policy trayectoria_revision_insertar on public.gth_trayectoria_revisiones to authenticated
  with check (autor=(select auth.uid()) and exists (
    select 1 from public.gth_trayectoria_analisis a join public.postulaciones p
      on p.aviso_id=a.aviso_id and p.clave=a.clave
    where a.id=analisis_id and a.version='trayectoria-v3'
      and a.huella=public.gth_trayectoria_huella(p.datos_json)
      and p.en_ultimo_csv=1 and (a.vigente_hasta is null or a.vigente_hasta>=current_date)
      and not exists(select 1 from public.gth_trayectoria_analisis nueva
        where nueva.aviso_id=a.aviso_id and nueva.clave=a.clave and nueva.version=a.version
          and nueva.huella=a.huella and (nueva.fecha_referencia,nueva.calculado_at,nueva.id)>(a.fecha_referencia,a.calculado_at,a.id))));

create or replace function public.gth_trayectoria_resumen(p_aviso text,p_desde integer default 0)
returns table(id_postulante text,analisis_id uuid,estado text,calculado_at timestamptz,revision text)
language sql stable security invoker set search_path='' as $$
  select p.id_postulante,a.id,
    case when a.id is null then 'pendiente'
      when a.huella<>public.gth_trayectoria_huella(p.datos_json) or a.version<>'trayectoria-v3'
        or a.vigente_hasta<current_date then 'desactualizado' else a.estado end,
    a.calculado_at,
    (select r.estado from public.gth_trayectoria_revisiones r where r.analisis_id=a.id order by r.creada_at desc,r.id desc limit 1)
  from public.postulaciones p
  left join lateral (select a.* from public.gth_trayectoria_analisis a
    where a.aviso_id=p.aviso_id and a.clave=p.clave
    order by (a.huella=public.gth_trayectoria_huella(p.datos_json) and a.version='trayectoria-v3') desc,
      a.fecha_referencia desc,a.calculado_at desc,a.id desc limit 1) a on true
  where p.aviso_id=p_aviso and p.en_ultimo_csv=1 and p.id_postulante is not null
  order by p.id_postulante,p.clave offset greatest(0,p_desde) limit 500;
$$;

revoke execute on function public.gth_trayectoria_campo_valido(text),public.gth_trayectoria_resumen(text,integer) from public,anon;
grant execute on function public.gth_trayectoria_campo_valido(text),public.gth_trayectoria_resumen(text,integer) to authenticated;
notify pgrst,'reload schema';
commit;


-- >>> supabase/migrations/20261023220000_requisitos_reglas_feedback.sql
-- Requisitos con peso por aviso, reglas de puntaje, su activación por aviso y feedback del ranking.
-- Aplicar en GTH_Bumeran después de superadministracion_y_sueldos. Solo agrega tablas y columnas vacías:
-- la web y el scraper actuales no las usan todavía (siguen con avisos.criterios y pesos iguales).
-- Sin FK a avisos, como gth_sueldos_ofertados: también admite convocatorias creadas manualmente.
-- El scraper entra con el rol postgres y no pasa por RLS.
begin;

-- Requisitos de cada aviso con su peso entero. Los activos de un aviso suman exactamente 100.
-- Los requisitos escritos a mano para una convocatoria van aquí con origen 'manual'.
create table public.gth_aviso_requisitos (
  id uuid primary key default gen_random_uuid(),
  aviso_id text not null check (length(aviso_id) between 1 and 250),
  etiqueta text not null check (length(btrim(etiqueta)) between 1 and 500),
  peso integer not null check (peso between 0 and 100),
  activo boolean not null default true,
  origen text not null default 'manual' check (origen in ('bumeran','manual')),
  orden integer not null default 0,
  actualizado_por uuid references auth.users(id) on delete set null default auth.uid(),
  actualizado_at timestamptz not null default now(),
  unique (aviso_id, etiqueta)
);
create index ix_aviso_requisitos_aviso on public.gth_aviso_requisitos(aviso_id, orden);

-- Catálogo de reglas que crean los usuarios. La descripción se compara con el CV como un requisito;
-- si cumple, se aplica el efecto con su valor (porcentaje entero).
create table public.gth_reglas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(btrim(nombre)) between 1 and 120),
  descripcion text not null check (length(btrim(descripcion)) between 1 and 2000),
  efecto text not null check (efecto in ('bono','penalizacion','alerta')),
  valor integer not null default 0 check (valor between 0 and 100),
  creado_por uuid references auth.users(id) on delete set null default auth.uid(),
  creado_at timestamptz not null default now(),
  actualizado_por uuid references auth.users(id) on delete set null default auth.uid(),
  actualizado_at timestamptz not null default now()
);

-- Reglas activadas a mano en cada aviso. Sin fila = la regla no aplica a ese aviso.
-- valor null = usa el valor del catálogo; con número, lo reemplaza solo en este aviso.
create table public.gth_aviso_reglas (
  aviso_id text not null check (length(aviso_id) between 1 and 250),
  regla_id uuid not null references public.gth_reglas(id) on delete cascade,
  activa boolean not null default true,
  valor integer check (valor is null or valor between 0 and 100),
  actualizado_por uuid references auth.users(id) on delete set null default auth.uid(),
  actualizado_at timestamptz not null default now(),
  primary key (aviso_id, regla_id)
);
create index ix_aviso_reglas_regla on public.gth_aviso_reglas(regla_id);

-- Feedback del equipo sobre el ranking: «no lo escogimos por…». Texto libre, para afinar reglas y pesos.
create table public.gth_feedback_ranking (
  id bigint generated always as identity primary key,
  aviso_id text not null check (length(aviso_id) between 1 and 250),
  id_postulante text not null check (length(id_postulante) between 1 and 250),
  posicion_sistema integer check (posicion_sistema is null or posicion_sistema > 0),
  decision text not null check (decision in ('no_escogido','escogido')),
  motivo text not null check (length(btrim(motivo)) between 1 and 4000),
  creado_por uuid references auth.users(id) on delete set null default auth.uid(),
  creado_at timestamptz not null default now()
);
create index ix_feedback_ranking_postulante on public.gth_feedback_ranking(aviso_id, id_postulante);

-- Puntaje con reglas aplicadas y su detalle. score conserva el puntaje puro de embeddings.
alter table public.ranking_embeddings add column if not exists score_reglas double precision;
alter table public.ranking_embeddings add column if not exists ajustes jsonb;

-- ------------------------------------------------------------------ sellos y validaciones
create function gth_privado.sello_por_aviso() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if TG_OP = 'UPDATE' and new.aviso_id <> old.aviso_id then raise exception 'El aviso no es editable'; end if;
  new.actualizado_por := auth.uid(); new.actualizado_at := now();
  return new;
end; $$;

create function gth_privado.sello_regla() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then new.creado_por := auth.uid(); new.creado_at := now();
  else new.creado_por := old.creado_por; new.creado_at := old.creado_at; end if;
  new.actualizado_por := auth.uid(); new.actualizado_at := now();
  return new;
end; $$;

create function gth_privado.sello_feedback() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then new.creado_por := auth.uid(); new.creado_at := now();
  elsif new.aviso_id <> old.aviso_id or new.id_postulante <> old.id_postulante then
    raise exception 'El aviso y el postulante no son editables';
  else new.creado_por := old.creado_por; new.creado_at := old.creado_at; end if;
  return new;
end; $$;

-- Se revisa al cerrar la transacción: un guardado puede mover varios pesos a la vez.
create function gth_privado.validar_pesos_aviso() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  v_aviso text := coalesce(new.aviso_id, old.aviso_id);
  v_total integer; v_activos integer; v_suma integer;
begin
  select count(*), count(*) filter (where activo), coalesce(sum(peso) filter (where activo), 0)
    into v_total, v_activos, v_suma
    from public.gth_aviso_requisitos where aviso_id = v_aviso;
  if v_total > 0 and v_activos = 0 then
    raise exception 'El aviso % debe tener al menos un requisito activo', v_aviso;
  end if;
  if v_activos > 0 and v_suma <> 100 then
    raise exception 'Los pesos activos del aviso % suman % y deben sumar 100', v_aviso, v_suma;
  end if;
  return null;
end; $$;

revoke all on function gth_privado.sello_por_aviso(), gth_privado.sello_regla(), gth_privado.sello_feedback(),
  gth_privado.validar_pesos_aviso() from public, anon;

create trigger sello_aviso_requisito before insert or update on public.gth_aviso_requisitos
  for each row execute function gth_privado.sello_por_aviso();
create constraint trigger pesos_suman_100 after insert or update or delete on public.gth_aviso_requisitos
  deferrable initially deferred for each row execute function gth_privado.validar_pesos_aviso();
create trigger sello_regla before insert or update on public.gth_reglas
  for each row execute function gth_privado.sello_regla();
create trigger sello_aviso_regla before insert or update on public.gth_aviso_reglas
  for each row execute function gth_privado.sello_por_aviso();
create trigger sello_feedback before insert or update on public.gth_feedback_ranking
  for each row execute function gth_privado.sello_feedback();

-- ------------------------------------------------------------------ seguridad (RLS)
-- Todos los usuarios con sesión trabajan sobre los avisos que pueden ver (gth_puede_ver_aviso).
-- El catálogo de reglas no depende de un aviso: por ahora lo edita cualquier usuario con sesión.
alter table public.gth_aviso_requisitos enable row level security;
alter table public.gth_reglas enable row level security;
alter table public.gth_aviso_reglas enable row level security;
alter table public.gth_feedback_ranking enable row level security;
revoke all on public.gth_aviso_requisitos, public.gth_reglas, public.gth_aviso_reglas, public.gth_feedback_ranking
  from public, anon, authenticated;
grant select, insert, update, delete on public.gth_aviso_requisitos, public.gth_reglas, public.gth_aviso_reglas,
  public.gth_feedback_ranking to authenticated;
grant all on public.gth_aviso_requisitos, public.gth_reglas, public.gth_aviso_reglas, public.gth_feedback_ranking
  to service_role;

create policy requisitos_por_aviso on public.gth_aviso_requisitos for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));

create policy reglas_libres on public.gth_reglas for all to authenticated
  using (true) with check (true);

create policy reglas_por_aviso on public.gth_aviso_reglas for all to authenticated
  using (public.gth_puede_ver_aviso(aviso_id)) with check (public.gth_puede_ver_aviso(aviso_id));

-- Cada uno edita o borra solo su propio feedback.
create policy feedback_lectura on public.gth_feedback_ranking for select to authenticated
  using (public.gth_puede_ver_aviso(aviso_id));
create policy feedback_alta on public.gth_feedback_ranking for insert to authenticated
  with check (public.gth_puede_ver_aviso(aviso_id));
create policy feedback_edicion on public.gth_feedback_ranking for update to authenticated
  using (creado_por = (select auth.uid()) and public.gth_puede_ver_aviso(aviso_id))
  with check (public.gth_puede_ver_aviso(aviso_id));
create policy feedback_borrado on public.gth_feedback_ranking for delete to authenticated
  using (creado_por = (select auth.uid()) and public.gth_puede_ver_aviso(aviso_id));

commit;


-- >>> supabase/migrations/20261023230000_pesos_independientes.sql
-- Pesos independientes: cada requisito vale de 0 a 100 por sí mismo y ya no tienen que sumar 100.
-- El puntaje pondera con peso / suma de pesos (igual que matching_llm.py), así que la escala no cambia el resultado.
-- Aplicar después de requisitos_reglas_feedback. No modifica datos.
begin;

drop trigger pesos_suman_100 on public.gth_aviso_requisitos;
drop function gth_privado.validar_pesos_aviso();

commit;


-- >>> supabase/migrations/20261024120000_ranking_recalculos.sql
-- «Recalcular puntaje» (Requisitos y pesos): la web deja el pedido en ranking_recalculos y el servidor de la laptop de
-- GTH (python -m scraping.multitest_servidor, el mismo de Multitest) lo toma, recalcula el ranking e5 del aviso con los
-- requisitos y pesos de gth_aviso_requisitos y lo guarda en ranking_embeddings. Usa el mismo latido (servidor_latido,
-- servicio 'multitest'). Aplicar después de pesos_independientes.
begin;
create table if not exists public.ranking_recalculos (
  id            bigint generated always as identity primary key,
  aviso_id      text not null check (length(aviso_id) between 1 and 250),
  estado        text not null default 'pendiente' check (estado in ('pendiente', 'en_curso', 'ok', 'error')),
  mensaje       text,
  creado_por    uuid not null default auth.uid(),
  creado_at     timestamptz not null default now(),
  tomado_at     timestamptz,
  terminado_at  timestamptz
);
create index if not exists ix_ranking_recalculos_pend on public.ranking_recalculos(estado, creado_at);
create index if not exists ix_ranking_recalculos_aviso on public.ranking_recalculos(aviso_id, creado_at desc);

alter table public.ranking_recalculos enable row level security;
-- Cualquier usuario con sesión que vea el aviso pide el recálculo y ve el estado de los pedidos del aviso (también los
-- de sus compañeros). Cerrarlos lo hace solo el servidor, con la conexión directa a la base (sin RLS).
create policy ranking_recalculos_leer on public.ranking_recalculos for select to authenticated
  using (public.gth_puede_ver_aviso(aviso_id));
create policy ranking_recalculos_pedir on public.ranking_recalculos for insert to authenticated
  with check (estado = 'pendiente' and creado_por = auth.uid() and public.gth_puede_ver_aviso(aviso_id));

revoke all on public.ranking_recalculos from anon, authenticated;
grant select, insert on public.ranking_recalculos to authenticated;
grant all on public.ranking_recalculos to service_role;
commit;


-- >>> supabase/migrations/20261025120000_correos_enviados.sql
-- Registro de los correos que la web envía a postulantes desde la cuenta de GTH (server/correo.ts, api/correo.ts).
-- Lo escribe solo el servidor con la clave service_role; no guarda el cuerpo del mensaje. Aplicar después de
-- ranking_recalculos. Solo agrega una tabla: no modifica datos ni tablas existentes.
begin;
create table if not exists public.gth_correos_enviados (
  id            bigint generated always as identity primary key,
  creado_por    uuid references auth.users(id) on delete set null,
  tipo          text not null check (tipo in ('agradecimiento', 'entrevista', 'perfil')),
  aviso_id      text check (aviso_id is null or length(aviso_id) between 1 and 250),
  id_postulante text check (id_postulante is null or length(id_postulante) between 1 and 250),
  destinatario  text not null check (length(destinatario) between 3 and 200),
  asunto        text not null check (length(asunto) between 1 and 300),
  estado        text not null check (estado in ('enviado', 'error')),
  error         text,
  creado_at     timestamptz not null default now()
);
create index if not exists ix_correos_enviados_aviso on public.gth_correos_enviados(aviso_id, id_postulante, creado_at desc);

alter table public.gth_correos_enviados enable row level security;
-- Los usuarios con sesión ven los correos de los avisos que pueden ver; nadie escribe desde la web.
create policy correos_enviados_leer on public.gth_correos_enviados for select to authenticated
  using (aviso_id is not null and public.gth_puede_ver_aviso(aviso_id));
revoke all on public.gth_correos_enviados from anon, authenticated;
grant select on public.gth_correos_enviados to authenticated;
grant all on public.gth_correos_enviados to service_role;
commit;


-- >>> supabase/migrations/20261026120000_correos_credenciales.sql
-- «Enviar credenciales al correo» (Usuarios y permisos): el registro de correos admite el tipo 'credenciales'.
-- Solo amplía la lista de tipos permitidos; no modifica datos. No se guarda el cuerpo (ni la contraseña).
begin;
alter table public.gth_correos_enviados drop constraint gth_correos_enviados_tipo_check;
alter table public.gth_correos_enviados add constraint gth_correos_enviados_tipo_check
  check (tipo in ('agradecimiento', 'entrevista', 'perfil', 'credenciales'));
commit;


-- >>> supabase/migrations/20261026231414_criterios_sueldo_estricto_manejable.sql
-- Ejecutar en GTHC después de superadministracion_y_sueldos.
-- Conserva importes, permisos RLS y el sello de autor/fecha existentes.
begin;
alter table public.gth_sueldos_ofertados
  add column modo_sueldo text not null default 'estricto'
  constraint gth_sueldo_modo_valido check (modo_sueldo in ('estricto', 'manejable'));
comment on column public.gth_sueldos_ofertados.modo_sueldo is
  'Estricto por defecto. Manejable permite señalar negociación para puntaje vigente >= 0.70; no aprueba el sueldo ni altera el ranking.';
commit;


-- >>> supabase/migrations/20261027120000_criterios_clasificacion.sql
-- «Criterios y pesos» (matriz de clasificación de Andrea): intensidad 0-100 de cada criterio por aviso y la penalización
-- por alta rotación. 50 = peso normal (Experiencia laboral empieza en 100). Sin fila = todos los valores por defecto.
-- El servidor de GTH (scraping/ranking.py) los lee al recalcular. Solo agrega una tabla: no modifica datos.
begin;
create table if not exists public.gth_aviso_criterios (
  aviso_id           text primary key check (length(aviso_id) between 1 and 250),
  experiencia        integer not null default 100 check (experiencia between 0 and 100),
  rotacion           numeric(3,2) not null default 0.50 check (rotacion between 0 and 1),
  rubro              integer not null default 50 check (rubro between 0 and 100),
  sobrecalificacion  integer not null default 50 check (sobrecalificacion between 0 and 100),
  escala_empresa     integer not null default 50 check (escala_empresa between 0 and 100),
  actualizado_por    uuid references auth.users(id) on delete set null default auth.uid(),
  actualizado_at     timestamptz not null default now()
);

create or replace function gth_privado.sello_criterios() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if TG_OP = 'UPDATE' and new.aviso_id <> old.aviso_id then raise exception 'El aviso no es editable'; end if;
  new.actualizado_por := auth.uid(); new.actualizado_at := now();
  return new;
end; $$;
revoke all on function gth_privado.sello_criterios() from public, anon;
create trigger sello_criterios before insert or update on public.gth_aviso_criterios
  for each row execute function gth_privado.sello_criterios();

alter table public.gth_aviso_criterios enable row level security;
-- Todos los que ven el aviso consultan los criterios; los cambia solo la superadministración (como el criterio salarial).
create policy criterios_lectura on public.gth_aviso_criterios for select to authenticated
  using (public.gth_puede_ver_aviso(aviso_id));
create policy criterios_alta on public.gth_aviso_criterios for insert to authenticated
  with check (gth_privado.es_superadmin() and public.gth_puede_ver_aviso(aviso_id));
create policy criterios_edicion on public.gth_aviso_criterios for update to authenticated
  using (gth_privado.es_superadmin() and public.gth_puede_ver_aviso(aviso_id))
  with check (gth_privado.es_superadmin() and public.gth_puede_ver_aviso(aviso_id));
revoke all on public.gth_aviso_criterios from anon, authenticated;
grant select, insert, update on public.gth_aviso_criterios to authenticated;
grant all on public.gth_aviso_criterios to service_role;
commit;


-- >>> supabase/migrations/20261028120000_calibracion_y_banderas.sql
-- 1) «Recalcular puntaje» solo con cambios: hora de la última edición de las calibraciones de cada aviso (Requisitos y
--    pesos, Criterios y pesos, Sueldo), incluidos los borrados. La web lo compara con el último recálculo exitoso.
-- 2) Red flag / green flag en los comentarios internos: un comentario puede tener solo la bandera, sin texto.
-- No modifica datos existentes.
begin;
create table if not exists public.gth_aviso_calibracion (
  aviso_id    text primary key check (length(aviso_id) between 1 and 250),
  editado_at  timestamptz not null default now()
);
alter table public.gth_aviso_calibracion enable row level security;
create policy calibracion_lectura on public.gth_aviso_calibracion for select to authenticated
  using (public.gth_puede_ver_aviso(aviso_id));
revoke all on public.gth_aviso_calibracion from anon, authenticated;
grant select on public.gth_aviso_calibracion to authenticated;
grant all on public.gth_aviso_calibracion to service_role;

-- Solo la escriben los disparadores (security definer): la web no la edita directamente.
create or replace function gth_privado.marcar_calibracion() returns trigger
language plpgsql security definer set search_path = '' as $$
declare aviso text := coalesce(new.aviso_id, old.aviso_id);
begin
  insert into public.gth_aviso_calibracion (aviso_id, editado_at) values (aviso, now())
    on conflict (aviso_id) do update set editado_at = excluded.editado_at;
  return null;
end; $$;
revoke all on function gth_privado.marcar_calibracion() from public, anon;
grant execute on function gth_privado.marcar_calibracion() to authenticated;

drop trigger if exists calibracion_requisitos on public.gth_aviso_requisitos;
create trigger calibracion_requisitos after insert or update or delete on public.gth_aviso_requisitos
  for each row execute function gth_privado.marcar_calibracion();
drop trigger if exists calibracion_criterios on public.gth_aviso_criterios;
create trigger calibracion_criterios after insert or update or delete on public.gth_aviso_criterios
  for each row execute function gth_privado.marcar_calibracion();
drop trigger if exists calibracion_sueldo on public.gth_sueldos_ofertados;
create trigger calibracion_sueldo after insert or update or delete on public.gth_sueldos_ofertados
  for each row execute function gth_privado.marcar_calibracion();

alter table public.comentarios_internos add column if not exists bandera text check (bandera in ('roja', 'verde'));
alter table public.comentarios_internos drop constraint if exists comentarios_internos_texto_check;
alter table public.comentarios_internos add constraint comentarios_internos_texto_check
  check (length(btrim(texto)) <= 4000 and (length(btrim(texto)) >= 1 or bandera is not null));
commit;


-- >>> supabase/migrations/20261029120000_diccionario_empresas_y_correos.sql
-- 1) Diccionario de empresas Tier 1 / Tier 1.5 editable (antes solo en scraping/empresas_peru.py, que queda como copia de
--    respaldo). Cada fila es un nombre o alias normalizado (minúsculas, sin tildes) que se busca como palabras completas
--    en la empresa del CV; `exacto` = solo si es el nombre completo (siglas como «ey» o «tasa»). Lo edita quien tenga
--    gth_perfiles.editar_diccionario (todos por defecto; un administrador puede quitarlo). Agregar o quitar una empresa
--    marca para recalcular solo los avisos con postulantes que trabajaron en ella.
-- 2) Correo corregido de un postulante (por su ID de Bumeran): vale en todos sus avisos y no lo pisa el CSV de Bumeran.
-- No modifica datos existentes (el diccionario se carga con scraping/cargar_diccionario.py).
begin;
alter table public.gth_perfiles add column if not exists editar_diccionario boolean not null default true;

create table if not exists public.gth_empresas_diccionario (
  alias       text primary key check (length(alias) between 2 and 120 and alias = lower(alias)),
  tier        text not null check (tier in ('Tier 1', 'Tier 1.5')),
  sector      text not null check (length(sector) between 1 and 80),
  exacto      boolean not null default false,
  origen      text not null default 'equipo' check (origen in ('base', 'equipo')),
  creado_por  uuid references auth.users(id) on delete set null default auth.uid(),
  creado_at   timestamptz not null default now()
);

create or replace function gth_privado.puede_editar_diccionario() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.gth_perfiles where user_id = auth.uid() and activo and editar_diccionario);
$$;
revoke all on function gth_privado.puede_editar_diccionario() from public, anon;
grant execute on function gth_privado.puede_editar_diccionario() to authenticated;

alter table public.gth_empresas_diccionario enable row level security;
create policy diccionario_lectura on public.gth_empresas_diccionario for select to authenticated using (true);
create policy diccionario_alta on public.gth_empresas_diccionario for insert to authenticated
  with check (gth_privado.puede_editar_diccionario() and origen = 'equipo');
create policy diccionario_baja on public.gth_empresas_diccionario for delete to authenticated
  using (gth_privado.puede_editar_diccionario());
revoke all on public.gth_empresas_diccionario from anon, authenticated;
grant select, insert, delete on public.gth_empresas_diccionario to authenticated;
grant all on public.gth_empresas_diccionario to service_role;

-- Avisos con postulantes que trabajaron en la empresa agregada o quitada: quedan con cambios por recalcular.
create or replace function gth_privado.marcar_avisos_empresa() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  fila public.gth_empresas_diccionario := coalesce(new, old);
  patron text := '(^|[^a-z0-9])' || regexp_replace(fila.alias, '([.^$*+?()\[\]{}|\\-])', '\\\1', 'g') || '([^a-z0-9]|$)';
begin
  insert into public.gth_aviso_calibracion (aviso_id, editado_at)
  select distinct p.aviso_id, now()
    from public.postulaciones p, jsonb_each_text(p.datos_json) e
   where p.en_ultimo_csv = 1 and e.key ~ '^Exp\[\d+\] Empresa$' and public.gth_sin_tildes(e.value) ~ patron
  on conflict (aviso_id) do update set editado_at = excluded.editado_at;
  return null;
end; $$;
revoke all on function gth_privado.marcar_avisos_empresa() from public, anon;
grant execute on function gth_privado.marcar_avisos_empresa() to authenticated;
drop trigger if exists diccionario_recalculo on public.gth_empresas_diccionario;
create trigger diccionario_recalculo after insert or delete on public.gth_empresas_diccionario
  for each row execute function gth_privado.marcar_avisos_empresa();

create table if not exists public.gth_correos_postulante (
  id_postulante   text primary key check (length(id_postulante) between 1 and 250),
  email           text not null check (email ~* '^[^\s@]+@[^\s@]+\.[^\s@]+$' and length(email) <= 254),
  actualizado_por uuid references auth.users(id) on delete set null default auth.uid(),
  actualizado_at  timestamptz not null default now()
);
create or replace function gth_privado.sello_correo() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.email := lower(btrim(new.email)); new.actualizado_por := auth.uid(); new.actualizado_at := now();
  return new;
end; $$;
revoke all on function gth_privado.sello_correo() from public, anon;
grant execute on function gth_privado.sello_correo() to authenticated;
drop trigger if exists sello_correo on public.gth_correos_postulante;
create trigger sello_correo before insert or update on public.gth_correos_postulante
  for each row execute function gth_privado.sello_correo();
alter table public.gth_correos_postulante enable row level security;
create policy correos_lectura on public.gth_correos_postulante for select to authenticated
  using (exists (select 1 from public.gth_perfiles where user_id = (select auth.uid()) and activo));
create policy correos_alta on public.gth_correos_postulante for insert to authenticated
  with check (exists (select 1 from public.gth_perfiles where user_id = (select auth.uid()) and activo));
create policy correos_edicion on public.gth_correos_postulante for update to authenticated
  using (exists (select 1 from public.gth_perfiles where user_id = (select auth.uid()) and activo))
  with check (exists (select 1 from public.gth_perfiles where user_id = (select auth.uid()) and activo));
revoke all on public.gth_correos_postulante from anon, authenticated;
grant select, insert, update on public.gth_correos_postulante to authenticated;
grant all on public.gth_correos_postulante to service_role;
commit;


-- >>> demo/05_permisos.sql (permisos de la web en proyectos nuevos de Supabase)
grant delete, insert, select, update on public.avisos to authenticated;
grant delete, insert, select on public.avisos_confidenciales to authenticated;
grant delete, insert, select, update on public.comentarios_internos to authenticated;
grant delete, insert, select, update on public.cvs to authenticated;
grant delete, insert, select, update on public.en_revision to authenticated;
grant delete, insert, select, update on public.gth_acciones to authenticated;
grant insert, select, update on public.gth_avance to authenticated;
grant select on public.gth_aviso_calibracion to authenticated;
grant insert, select, update on public.gth_aviso_criterios to authenticated;
grant delete, insert, select, update on public.gth_aviso_reglas to authenticated;
grant delete, insert, select, update on public.gth_aviso_requisitos to authenticated;
grant select on public.gth_colaboradores to authenticated;
grant select on public.gth_correos_enviados to authenticated;
grant insert, select, update on public.gth_correos_postulante to authenticated;
grant delete, insert, select on public.gth_empresas_diccionario to authenticated;
grant delete, insert, select, update on public.gth_feedback_ranking to authenticated;
grant select, update on public.gth_perfiles to authenticated;
grant delete, insert, select, update on public.gth_reglas to authenticated;
grant insert, select, update on public.gth_sueldos_ofertados to authenticated;
grant select on public.gth_trayectoria_analisis to authenticated;
grant select on public.gth_trayectoria_revisiones to authenticated;
grant insert, select on public.multitest_envios to authenticated;
grant delete, insert, select, update on public.postulaciones to authenticated;
grant delete, insert, select, update on public.ranking_embeddings to authenticated;
grant insert, select on public.ranking_recalculos to authenticated;
grant delete, insert, select, update on public.scrape_runs to authenticated;
grant select on public.servidor_latido to authenticated;
grant delete, insert, select, update on public.solicitudes to authenticated;
grant delete, insert, select, update on public.v_base_postulantes to authenticated;
grant delete, insert, select, update on public.v_gth_personas_base to authenticated;
grant delete, insert, select, update on public.v_postulaciones to authenticated;
grant usage, select on sequence public.gth_correos_enviados_id_seq to authenticated;
grant usage, select on sequence public.gth_feedback_ranking_id_seq to authenticated;
grant usage, select on sequence public.multitest_envios_id_seq to authenticated;
grant usage, select on sequence public.ranking_recalculos_id_seq to authenticated;
grant usage, select on sequence public.scrape_runs_id_seq to authenticated;
grant usage, select on sequence public.solicitudes_id_seq to authenticated;
