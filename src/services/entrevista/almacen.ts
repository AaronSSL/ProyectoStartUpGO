// Videos y análisis de entrevistas, guardados en este navegador (IndexedDB). El video no se sube a ningún servidor.
import type { ResultadoEntrevista } from './tipos.ts';

export type RegistroEntrevista = { videoId: string; archivo: string; tipo: string; resultado?: ResultadoEntrevista };

const BASE = 'cvup-entrevistas';
let db: Promise<IDBDatabase> | null = null;

function abrir(): Promise<IDBDatabase> {
  db ??= new Promise((resolver, rechazar) => {
    const pedido = indexedDB.open(BASE, 1);
    pedido.onupgradeneeded = () => {
      pedido.result.createObjectStore('videos');
      pedido.result.createObjectStore('entrevistas');
    };
    pedido.onsuccess = () => resolver(pedido.result);
    pedido.onerror = () => { db = null; rechazar(new Error('Este navegador no permite guardar los videos (¿ventana privada?).')); };
  });
  return db;
}

async function operar<T>(almacen: 'videos' | 'entrevistas', modo: IDBTransactionMode, accion: (s: IDBObjectStore) => IDBRequest): Promise<T> {
  const base = await abrir();
  return new Promise<T>((resolver, rechazar) => {
    const pedido = accion(base.transaction(almacen, modo).objectStore(almacen));
    pedido.onsuccess = () => resolver(pedido.result as T);
    pedido.onerror = () => rechazar(pedido.error ?? new Error('No se pudo guardar en el navegador.'));
  });
}

/** Clave de una entrevista: aviso + postulación (cada aviso tiene su propio análisis). */
export const claveEntrevista = (jobId: string, applicationId: string) => `${jobId}|${applicationId}`;

export const almacenEntrevistas = {
  video: (id: string) => operar<Blob | undefined>('videos', 'readonly', (s) => s.get(id)),
  guardarVideo: (id: string, blob: Blob) => operar<IDBValidKey>('videos', 'readwrite', (s) => s.put(blob, id)),
  borrarVideo: (id: string) => operar<undefined>('videos', 'readwrite', (s) => s.delete(id)),
  leer: (clave: string) => operar<RegistroEntrevista | undefined>('entrevistas', 'readonly', (s) => s.get(clave)),
  guardar: (clave: string, r: RegistroEntrevista) => operar<IDBValidKey>('entrevistas', 'readwrite', (s) => s.put(r, clave)),
  /** Todas las entrevistas de un aviso, por postulación. */
  async delAviso(jobId: string): Promise<Record<string, RegistroEntrevista>> {
    const base = await abrir();
    return new Promise((resolver, rechazar) => {
      const out: Record<string, RegistroEntrevista> = {};
      const pedido = base.transaction('entrevistas', 'readonly').objectStore('entrevistas')
        .openCursor(IDBKeyRange.bound(`${jobId}|`, `${jobId}|￿`));
      pedido.onsuccess = () => {
        const cursor = pedido.result;
        if (!cursor) { resolver(out); return; }
        out[String(cursor.key).slice(jobId.length + 1)] = cursor.value as RegistroEntrevista;
        cursor.continue();
      };
      pedido.onerror = () => rechazar(pedido.error ?? new Error('No se pudieron leer las entrevistas.'));
    });
  },
};

/** Preferencias por aviso (quién está invitado a entrevista y el peso del CV en el puntaje final). */
export function leerPreferencia<T>(clave: string, porDefecto: T): T {
  try { const v = localStorage.getItem(`cvup.entrevistas.${clave}`); return v === null ? porDefecto : JSON.parse(v) as T; }
  catch { return porDefecto; }
}
export function guardarPreferencia(clave: string, valor: unknown) {
  try { localStorage.setItem(`cvup.entrevistas.${clave}`, JSON.stringify(valor)); } catch { /* sin almacenamiento: dura la sesión */ }
}
