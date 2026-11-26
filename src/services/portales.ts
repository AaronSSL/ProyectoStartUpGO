// Bolsas de trabajo integradas con CV UP. Cada postulante trae su portal de origen en la columna «Fuente» del registro
// (en la demo: demo/generar_demo.py y demo/04_fuentes_portales.sql); sin esa columna se asume Bumeran.
import type { SupabaseClient } from '@supabase/supabase-js';

export type Portal = 'bumeran' | 'linkedin' | 'computrabajo';

export const PORTALES: { id: Portal; nombre: string; sigla: string; color: string; detalle: string }[] = [
  { id: 'bumeran', nombre: 'Bumeran', sigla: 'B', color: '#d81f5c', detalle: 'Avisos publicados y postulaciones, con el perfil completo y las respuestas a las preguntas del aviso.' },
  { id: 'linkedin', nombre: 'LinkedIn', sigla: 'in', color: '#0a66c2', detalle: 'Postulantes de tus empleos publicados en LinkedIn, con su experiencia y formación.' },
  { id: 'computrabajo', nombre: 'Computrabajo', sigla: 'C', color: '#1f6fb5', detalle: 'Ofertas activas y candidatos inscritos, con su hoja de vida.' },
];

/** Portal a partir del texto de la fuente («LinkedIn», «Computrabajo», «Bumeran (archivo)»…); null si no es un portal. */
export function portalDe(fuente: string | null | undefined): Portal | null {
  const f = (fuente || '').toLowerCase();
  return f.includes('linkedin') ? 'linkedin' : f.includes('computrabajo') ? 'computrabajo' : f.includes('bumeran') ? 'bumeran' : null;
}

export const datosPortal = (p: Portal) => PORTALES.find((x) => x.id === p)!;

export type ConteoPortales = { porAviso: Record<string, Record<Portal, number>>; total: Record<Portal, number> };

const vacio = (): Record<Portal, number> => ({ bumeran: 0, linkedin: 0, computrabajo: 0 });

/** Cuántos postulantes llegan de cada portal, en total y por aviso (solo los del último registro de cada aviso). */
export async function contarPorPortal(client: SupabaseClient): Promise<ConteoPortales> {
  const porAviso: ConteoPortales['porAviso'] = {};
  const total = vacio();
  for (let desde = 0; ; desde += 1000) {
    const { data, error } = await client.from('postulaciones').select('aviso_id, fuente:datos_json->>Fuente')
      .eq('en_ultimo_csv', 1).order('aviso_id').order('clave').range(desde, desde + 999);
    if (error) throw new Error('No se pudo leer de qué portal llega cada postulante.');
    for (const fila of (data || []) as { aviso_id: string; fuente: string | null }[]) {
      const p = portalDe(fila.fuente) || 'bumeran';
      (porAviso[fila.aviso_id] ||= vacio())[p] += 1;
      total[p] += 1;
    }
    if (!data || data.length < 1000) break;
  }
  return { porAviso, total };
}
