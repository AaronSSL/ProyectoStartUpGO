// Prueba los SQL de la demo en un Postgres local (PGlite), sin tocar Supabase:
//   node demo/probar_demo.mjs
// Corre 01 → 02a…02d → 03 como en Supabase y luego consulta como la web, con sesión de la cuenta de la demo.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync, readdirSync } from 'node:fs';
import assert from 'node:assert/strict';

const sql = (f) => readFileSync(new URL(f, import.meta.url), 'utf8');
const db = new PGlite();
const DATOS = readdirSync(new URL('.', import.meta.url)).filter((f) => /^02.*_datos_.*\.sql$/.test(f)).sort();
const USER = '11111111-1111-1111-1111-111111111111';

// Lo mínimo de Supabase que usan los SQL: roles y el esquema auth.
await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth;
  create table auth.users(id uuid primary key, email text);
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('email', current_setting('request.jwt.claim.email',true))$$;
  grant usage on schema auth to authenticated;`);

for (const f of ['01_estructura.sql', ...DATOS]) {
  const t = Date.now();
  await db.exec(sql(f));
  console.log(`✓ ${f} (${Date.now() - t} ms)`);
}
await db.query(`insert into auth.users values ($1, 'demo@cvup.pe')`, [USER]);
await db.exec(sql('03_usuario_demo.sql'));
console.log('✓ 03_usuario_demo.sql');

// Como la web: rol authenticated con la sesión de la cuenta de la demo (supabase-js respeta RLS).
await db.exec(`grant select on all tables in schema public to authenticated; set role authenticated`);
await db.query(`select set_config('request.jwt.claim.sub', $1, false), set_config('request.jwt.claim.email', 'demo@cvup.pe', false)`, [USER]);

const one = async (q, p = []) => (await db.query(q, p)).rows;
const perfil = (await one(`select nivel, activo, debe_cambiar_clave from public.gth_perfiles where user_id = $1`, [USER]))[0];
assert.deepEqual(perfil, { nivel: 'superadmin', activo: true, debe_cambiar_clave: false });

const avisos = await one(`select aviso_id, titulo, criterios_version, jsonb_array_length(criterios) n from public.avisos order by aviso_id`);
assert.equal(avisos.length, 5, 'cinco avisos visibles');
let total = 0;
for (const a of avisos) {
  const [{ n: post }] = await one(`select count(*)::int n from public.v_postulaciones where aviso_id = $1 and en_ultimo_csv = 1`, [a.aviso_id]);
  const rk = await one(`select ranking, score from public.ranking_embeddings where aviso_id = $1 and criterios_version = $2 order by ranking`, [a.aviso_id, a.criterios_version]);
  assert.equal(rk.length, post, `${a.titulo}: todos los postulantes tienen ranking con la versión vigente de criterios`);
  assert.deepEqual(rk.map((r) => r.ranking), rk.map((_, i) => i + 1), `${a.titulo}: ranking 1..n sin huecos`);
  total += post;
  console.log(`  ${a.titulo}: ${post} postulantes, ${a.n} requisitos, puntaje ${rk.at(-1).score.toFixed(2)}–${rk[0].score.toFixed(2)}`);
}

const base = (await one(`select public.gth_base_centralizada('{}'::jsonb, 1, 50, true) as d`))[0].d;
assert.equal(base.total, total, 'base centralizada con todas las personas');
const tray = await one(`select estado, count(*)::int n from public.gth_trayectoria_analisis group by 1 order by 1`);
assert.ok(tray.some((r) => r.estado === 'patron_detectado'), 'hay alertas de rotación');
const resumen = await one(`select count(*)::int n from public.gth_trayectoria_resumen($1)`, [avisos[0].aviso_id]);
assert.ok(resumen[0].n > 0, 'resumen de trayectoria del aviso');
const [{ n: empresas }] = await one(`select count(*)::int n from public.gth_empresas_diccionario`);
console.log(`  Base centralizada: ${base.total} personas · trayectoria: ${tray.map((r) => `${r.estado} ${r.n}`).join(', ')} · empresas: ${empresas}`);

// Lo que un visitante puede hacer en la feria, y que 02a deja como nuevo al volver a correrlo
await db.query(`insert into public.en_revision(aviso_id, id_postulante) select aviso_id, id_postulante from public.postulaciones limit 1`);
await db.query(`insert into public.gth_aviso_criterios(aviso_id, experiencia) values ($1, 80)`, [avisos[0].aviso_id]);
await db.exec('reset role');
for (const f of DATOS) await db.exec(sql(f));
const [{ n: marcas }] = await one(`select (select count(*) from public.en_revision) + (select count(*) from public.gth_aviso_criterios) as n`);
assert.equal(Number(marcas), 0, 'volver a correr 02a…02d deja la demo como nueva');
console.log('✓ Reinicio de la demo (volver a correr todos los 02)');
console.log(`\nTodo bien: ${avisos.length} avisos y ${total} postulantes ficticios.`);
