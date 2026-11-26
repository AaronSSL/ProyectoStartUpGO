// Tipos del análisis de entrevistas en video (portado de la web de Palomar Talent / CV UP, src/lib/tipos.ts).
export type Palabra = { w: string; ini: number; fin: number };
export type Segmento = { inicio: number; fin: number; texto: string; palabras: Palabra[] };
export type Transcripcion = {
  segmentos: Segmento[];
  duracion: number;
  modelo: string;
  dispositivo: string;
  tiemposPorPalabra: boolean;   // false: tiempos de cada palabra estimados dentro de su frase
};

export type MetricasHabla = {
  palabras: number; duracion: number; tiempoHabla: number; ppm: number;
  pausas: number; pausasLargas: number; pausaMax: number;
  muletillas: Record<string, number>; muletillasTotal: number; muletillas100: number;
  repeticiones: number; repeticiones100: number;
};
export type EvidenciaEntrevista = {
  requisito: string; sim: number; negacion: boolean; puntaje: number; evidencia: string; inicio: number; fin: number;
};
export type ResultadoEntrevista = {
  puntaje: number; contenido: number; fluidez: number; claridad: number;
  metricas: MetricasHabla;
  porRequisito: EvidenciaEntrevista[];
  observaciones: string[];
  firma: string;
  transcripcion: Transcripcion;
  analizadoAt: string;
};

/** Requisito del aviso con su peso (los criterios del ranking de CV). */
export type RequisitoEntrevista = { texto: string; peso: number };

export function pesosNormalizados(reqs: RequisitoEntrevista[]): number[] {
  const total = reqs.reduce((s, r) => s + Math.max(r.peso, 0), 0);
  return reqs.map((r) => (total ? Math.max(r.peso, 0) / total : 1 / Math.max(reqs.length, 1)));
}

/** Cambia si cambian los requisitos o los pesos: el análisis anterior queda desactualizado. */
export const firma = (reqs: RequisitoEntrevista[]) => reqs.map((r) => `${r.texto.trim()}:${r.peso}`).join('|');

export const mmss = (seg: number) => {
  const s = Math.max(0, Math.round(seg || 0));
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
};
