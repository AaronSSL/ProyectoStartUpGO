// Pruebas de la lógica de entrevistas portada de Palomar Talent (src/lib/logica.test.ts de esa carpeta).
import { describe, expect, it } from 'vitest';
import { contarMuletillas, contarRepeticiones, metricasHabla, niega, oraciones, puntajeRitmo, subtitulosVtt } from '../entrevista/analisis.ts';
import { cortarEnTramos } from '../entrevista/tramos.ts';
import { firma, type Segmento } from '../entrevista/tipos.ts';

// Transcripción real de Whisper small (transformers.js) de ejemplos/entrevistas/Diego_Ramos_entrevista.mp4
const DIEGO = 'E, este, bueno, mi nombre es Diego. Este, yo trabajo en un restaurante, o sea, en la cocina. E, preparo los platos y, este, ordeno los insumos. Digamos que, o sea, me gusta trabajar en equipo, no. Bueno, de cobranzas, E, no tengo experiencia, pero, este, puedo aprender.';
const LUCIA = 'Trabajo hace más de tres años en cobranzas, en financiera andina. Lo que más hago es negociar por teléfono acuerdos de pago y refinanciamientos.';

describe('Entrevista', () => {
  it('cuenta las muletillas reales de una transcripción de Whisper', () => {
    const m = contarMuletillas(DIEGO);
    expect(m['este…']).toBe(4);
    expect(m['o sea']).toBe(2);
    expect(m['eh / em / mmm']).toBe(3);
    expect(m.digamos).toBe(1);
    expect(m['¿no?']).toBe(1);
    expect(contarMuletillas(LUCIA)).toEqual({});
  });
  it('detecta la negación aunque el texto se parezca al requisito', () => {
    expect(niega('Bueno, de cobranzas, E, no tengo experiencia, pero, este, puedo aprender.')).toBe(true);
    expect(niega(LUCIA)).toBe(false);
  });
  it('mide ritmo y pausas largas con los tiempos de cada palabra', () => {
    const palabras = 'uno dos tres cuatro cinco seis.'.split(' ').map((w, i) => ({ w, ini: i * 0.4 + (i >= 3 ? 4 : 0), fin: i * 0.4 + 0.3 + (i >= 3 ? 4 : 0) }));
    const segs: Segmento[] = [{ inicio: 0, fin: palabras[5].fin, texto: 'uno dos tres cuatro cinco seis.', palabras }];
    const m = metricasHabla(segs, 7);
    expect(m.pausasLargas).toBe(1);
    expect(m.pausaMax).toBeGreaterThan(3);
    expect(oraciones(segs)).toHaveLength(1);
    expect(subtitulosVtt(segs)).toMatch(/^WEBVTT\n\n00:00:00.000 --> /);
  });
  it('premia el ritmo recomendado y castiga los extremos', () => {
    expect(puntajeRitmo(130)).toBe(100);
    expect(puntajeRitmo(60)).toBe(0);
    expect(puntajeRitmo(85)).toBeCloseTo(50);
  });
  it('cuenta frases reiniciadas sin confundirlas con muletillas', () => {
    expect(contarRepeticiones('yo yo trabajé en el el área, este este')).toBe(2);
  });
});



describe('Tramos de audio', () => {
  it('corta los audios largos en el silencio más cercano y no parte los cortos', () => {
    const sr = 100;   // muestreo bajo para la prueba
    const audio = new Float32Array(70 * sr).fill(0.5);
    audio.fill(0, 24 * sr, 25 * sr);     // silencios a los 24-25 s y 49-50 s
    audio.fill(0, 49 * sr, 50 * sr);
    const tramos = cortarEnTramos(audio, sr);
    expect(tramos.map((t) => Math.round(t.inicio))).toEqual([0, 24, 49]);
    expect(tramos.reduce((s, t) => s + t.audio.length, 0)).toBe(audio.length);
    expect(cortarEnTramos(new Float32Array(29 * sr), sr)).toHaveLength(1);
  });
});

describe('Firma de requisitos', () => {
  it('cambia si cambian los requisitos o sus pesos (el análisis queda desactualizado)', () => {
    const base = [{ texto: 'SQL', peso: 50 }, { texto: 'Power BI', peso: 50 }];
    expect(firma(base)).toBe(firma([{ texto: 'SQL ', peso: 50 }, { texto: 'Power BI', peso: 50 }]));
    expect(firma(base)).not.toBe(firma([{ texto: 'SQL', peso: 60 }, { texto: 'Power BI', peso: 40 }]));
  });
});
