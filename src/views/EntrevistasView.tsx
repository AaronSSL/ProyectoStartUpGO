import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Film, Mic, Play, RefreshCw, Trophy, UploadCloud, UserPlus, Video } from 'lucide-react';
import '../styles/entrevistas.css';
import { useApp } from '../context/AppContext.tsx';
import { Button } from '../components/common/Button.tsx';
import { Badge } from '../components/common/Badge.tsx';
import { StageBadge } from '../components/candidate/StageBadge.tsx';
import { PortalTag } from '../components/common/PortalTag.tsx';
import type { Application, Candidate, Stage } from '../types/index.ts';
import { analizarEntrevista, PESOS, subtitulosVtt, UMBRAL_SUSTENTO } from '../services/entrevista/analisis.ts';
import { ajustesIA, guardarAjustesIA, MODELOS_WHISPER, similitudes, transcribir } from '../services/entrevista/ia.ts';
import { almacenEntrevistas, claveEntrevista, guardarPreferencia, leerPreferencia, type RegistroEntrevista } from '../services/entrevista/almacen.ts';
import { firma, mmss, type RequisitoEntrevista } from '../services/entrevista/tipos.ts';

const VIDEO = 'video/*,audio/*,.mp4,.mov,.webm,.mkv,.m4a,.mp3,.wav';
const ETAPAS_ENTREVISTA: Stage[] = ['preseleccionado', 'en_entrevista', 'en_evaluacion', 'en_oferta', 'contratado'];
const EJEMPLOS = [
  { archivo: 'analista_datos_1.mp4', nombre: 'Analista de Datos · ejemplo 1 (sólido)' },
  { archivo: 'analista_datos_2.mp4', nombre: 'Analista de Datos · ejemplo 2 (intermedio)' },
  { archivo: 'analista_datos_3.mp4', nombre: 'Analista de Datos · ejemplo 3 (sin experiencia)' },
  { archivo: 'atencion_cliente_1.mp4', nombre: 'Atención al Cliente · ejemplo' },
];

const card: React.CSSProperties = {
  backgroundColor: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)',
  padding: '1.1rem 1.25rem', display: 'flex', flexDirection: 'column', gap: '0.75rem', minWidth: 0,
};
const ayuda: React.CSSProperties = { fontSize: '0.8rem', color: 'var(--text-secondary)' };
const nuevoId = () => crypto.randomUUID().replace(/-/g, '').slice(0, 12);
const puntajeCv = (app: Application) => (app.embeddingMatch ? app.embeddingMatch.score * 100 : null);

type Fila = { app: Application; cand: Candidate | undefined; registro?: RegistroEntrevista };

/** Proceso de selección 2: entrevistas en video analizadas con Whisper (en el navegador) y ranking CV + entrevista. */
export function EntrevistasView() {
  const { activeJob, activeJobApplications, appState, openCandidateDrawer, showToast } = useApp();
  const jobId = activeJob?.id || '';
  const [registros, setRegistros] = useState<Record<string, RegistroEntrevista>>({});
  const [invitados, setInvitados] = useState<string[]>([]);
  const [pesoCv, setPesoCv] = useState(50);
  const [seleccion, setSeleccion] = useState<string | null>(null);
  const [agregar, setAgregar] = useState('');

  useEffect(() => {
    if (!jobId) return;
    setInvitados(leerPreferencia<string[]>(`invitados.${jobId}`, []));
    setPesoCv(leerPreferencia<number>(`pesoCv.${jobId}`, 50));
    setSeleccion(null);
    almacenEntrevistas.delAviso(jobId).then(setRegistros).catch((e: Error) => showToast(e.message, 'error'));
  }, [jobId]);

  const requisitos: RequisitoEntrevista[] = useMemo(
    () => (activeJob?.criteria || []).map((c) => ({ texto: c.label, peso: c.weightPct })), [activeJob?.criteria]);
  const candidato = (app: Application) => appState.candidates.find((c) => c.id === app.candidateId);
  const porRanking = useMemo(() => [...activeJobApplications].sort((a, b) =>
    (a.embeddingMatch?.ranking ?? 1e9) - (b.embeddingMatch?.ranking ?? 1e9)), [activeJobApplications]);

  const filas: Fila[] = porRanking
    .filter((app) => ETAPAS_ENTREVISTA.includes(app.stage) || invitados.includes(app.id) || registros[app.id])
    .map((app) => ({ app, cand: candidato(app), registro: registros[app.id] }));
  const actual = filas.find((f) => f.app.id === seleccion) ?? filas[0];
  const disponibles = porRanking.filter((app) => !filas.some((f) => f.app.id === app.id)).slice(0, 40);

  const invitar = (ids: string[]) => {
    const nuevos = [...new Set([...invitados, ...ids])];
    setInvitados(nuevos);
    guardarPreferencia(`invitados.${jobId}`, nuevos);
    if (ids[0]) setSeleccion(ids[0]);
  };
  const guardarRegistro = async (appId: string, r: RegistroEntrevista) => {
    await almacenEntrevistas.guardar(claveEntrevista(jobId, appId), r);
    setRegistros((prev) => ({ ...prev, [appId]: r }));
  };
  const cambiarPeso = (v: number) => { setPesoCv(v); guardarPreferencia(`pesoCv.${jobId}`, v); };

  if (!activeJob) return <p role="status" className="import-card">Elige una convocatoria en la parte superior para ver sus entrevistas.</p>;

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap', marginBottom: '1.25rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
          <div style={{ width: '42px', height: '42px', borderRadius: 'var(--radius-md)', backgroundColor: 'var(--primary-red-subtle)',
            color: 'var(--primary-red)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Video size={22} />
          </div>
          <div>
            <h1 style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--text-primary)' }}>Entrevistas en video</h1>
            <p style={{ fontSize: '0.84rem', color: 'var(--text-secondary)', maxWidth: '760px' }}>
              Sube el video de la entrevista: Whisper lo transcribe en este navegador y CV UP mide qué tanto sustenta los requisitos
              de <strong>{activeJob.title}</strong> ({Math.round(PESOS.contenido * 100)} %), su fluidez ({Math.round(PESOS.fluidez * 100)} %)
              y su claridad ({Math.round(PESOS.claridad * 100)} %). El ranking final combina el CV y la entrevista.
            </p>
          </div>
        </div>
        <SelectorModelo />
      </div>

      <div className="entrevistas-layout">
        <aside style={{ ...card, gap: '0.6rem' }} aria-label="Candidatos a entrevista">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h2 style={{ fontSize: '0.95rem', fontWeight: 700 }}>Candidatos a entrevista</h2><span style={ayuda}>{filas.length}</span>
          </div>
          {!filas.length && <p style={ayuda}>Nadie está preseleccionado todavía. Agrega candidatos del ranking de CV para entrevistarlos.</p>}
          <div className="entrevistas-lista">
            {filas.map(({ app, cand, registro }) => (
              <button key={app.id} type="button" className="entrevistas-item focus-ring" aria-pressed={actual?.app.id === app.id} onClick={() => setSeleccion(app.id)}>
                <span style={{ minWidth: 0 }}>
                  <strong>{cand?.name || 'Candidato'}</strong><br />
                  <span style={ayuda}>CV #{app.embeddingMatch?.ranking ?? '—'}</span>
                </span>
                {registro?.resultado ? <Badge size="sm" variant="primary">{registro.resultado.puntaje.toFixed(0)}</Badge>
                  : registro ? <Badge size="sm" variant="info">Video listo</Badge> : <Badge size="sm" variant="warning">Sin video</Badge>}
              </button>
            ))}
          </div>
          {!filas.length && porRanking.length > 0 && <Button variant="primary" size="sm" icon={<UserPlus size={15} />}
            onClick={() => invitar(porRanking.slice(0, 3).map((a) => a.id))}>Agregar a los 3 primeros del ranking</Button>}
          {disponibles.length > 0 && <label style={{ display: 'grid', gap: '0.3rem', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
            Agregar del ranking de CV
            <select className="focus-ring" value={agregar} onChange={(e) => { if (e.target.value) invitar([e.target.value]); setAgregar(''); }}
              style={{ padding: '0.45rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-default)', background: 'var(--bg-surface)', color: 'var(--text-primary)' }}>
              <option value="">Elegir candidato…</option>
              {disponibles.map((app) => <option key={app.id} value={app.id}>#{app.embeddingMatch?.ranking ?? '—'} · {candidato(app)?.name}</option>)}
            </select>
          </label>}
        </aside>

        {actual ? <PanelEntrevista key={actual.app.id} fila={actual} requisitos={requisitos} jobId={jobId}
          onGuardar={(r) => guardarRegistro(actual.app.id, r)} onPerfil={() => openCandidateDrawer(actual.app)} />
          : <section style={{ ...card, alignItems: 'center', justifyContent: 'center', minHeight: '280px', textAlign: 'center' }}>
            <Film size={36} style={{ color: 'var(--text-muted)' }} />
            <p style={{ fontWeight: 600 }}>Elige o agrega un candidato para subir su entrevista</p>
          </section>}
      </div>

      <RankingFinal filas={filas} pesoCv={pesoCv} onPeso={cambiarPeso} onVer={(id) => setSeleccion(id)} />
    </div>
  );
}

function SelectorModelo() {
  const [ajustes, setAjustes] = useState(ajustesIA);
  const modelo = MODELOS_WHISPER.find((m) => m.id === ajustes.modelo) ?? MODELOS_WHISPER[0];
  return (
    <label style={{ display: 'grid', gap: '0.25rem', fontSize: '0.78rem', color: 'var(--text-secondary)', maxWidth: '300px' }} title={modelo.detalle}>
      Modelo de transcripción
      <select className="focus-ring" value={ajustes.modelo} onChange={(e) => { const a = { ...ajustes, modelo: e.target.value }; setAjustes(a); guardarAjustesIA(a); }}
        style={{ padding: '0.45rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-default)', background: 'var(--bg-surface)', color: 'var(--text-primary)' }}>
        {MODELOS_WHISPER.map((m) => <option key={m.id} value={m.id}>{m.nombre}</option>)}
      </select>
      <span>{modelo.detalle}</span>
    </label>
  );
}

function PanelEntrevista({ fila, requisitos, jobId, onGuardar, onPerfil }: {
  fila: Fila; requisitos: RequisitoEntrevista[]; jobId: string;
  onGuardar: (r: RegistroEntrevista) => Promise<void>; onPerfil: () => void;
}) {
  const { app, cand, registro } = fila;
  const video = useRef<HTMLVideoElement>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [progreso, setProgreso] = useState<{ texto: string; pct: number | null } | null>(null);
  const [error, setError] = useState('');
  const [tiempo, setTiempo] = useState(0);
  const e = registro?.resultado;
  const desactualizado = !!e && e.firma !== firma(requisitos);
  const esAudio = !!registro?.tipo.startsWith('audio/');

  useEffect(() => {
    let creada: string | null = null;
    let vivo = true;
    (registro ? almacenEntrevistas.video(registro.videoId) : Promise.resolve(undefined)).then((blob) => {
      if (!vivo) return;
      if (blob) { creada = URL.createObjectURL(blob); setUrl(creada); } else setUrl(null);
    });
    return () => { vivo = false; if (creada) URL.revokeObjectURL(creada); };
  }, [registro?.videoId]);

  const vtt = useMemo(() => (e ? URL.createObjectURL(new Blob([subtitulosVtt(e.transcripcion.segmentos)], { type: 'text/vtt' })) : null), [e]);
  useEffect(() => () => { if (vtt) URL.revokeObjectURL(vtt); }, [vtt]);

  const ir = (t: number) => { if (video.current) { video.current.currentTime = t; void video.current.play(); } };
  const guardarVideo = async (blob: Blob, nombre: string) => {
    setError('');
    try {
      const id = registro?.videoId ?? nuevoId();
      await almacenEntrevistas.guardarVideo(id, blob);
      await onGuardar({ videoId: id, archivo: nombre, tipo: blob.type || 'video/mp4' });
    } catch (err) { setError(err instanceof Error ? err.message : 'No se pudo guardar el video.'); }
  };
  const usarEjemplo = async (archivo: string) => {
    setProgreso({ texto: 'Descargando el video de ejemplo…', pct: null });
    try {
      const r = await fetch(`/demo/entrevistas/${archivo}`);
      if (!r.ok) throw new Error('No se encontró el video de ejemplo.');
      await guardarVideo(await r.blob(), archivo);
    } catch (err) { setError(err instanceof Error ? err.message : 'No se pudo descargar el video de ejemplo.'); }
    finally { setProgreso(null); }
  };
  const analizar = async (retranscribir: boolean) => {
    setError('');
    if (!registro) return;
    try {
      let trans = !retranscribir && e ? e.transcripcion : null;
      if (!trans) {
        const blob = await almacenEntrevistas.video(registro.videoId);
        if (!blob) throw new Error('Primero sube el video de la entrevista.');
        trans = await transcribir(blob, (texto, pct) => setProgreso({ texto, pct }));
      }
      if (!requisitos.length) throw new Error('El aviso no tiene requisitos con los que comparar la entrevista.');
      setProgreso({ texto: 'Comparando lo que dijo con los requisitos del aviso…', pct: null });
      const resultado = await analizarEntrevista(trans, requisitos, (q, t) => similitudes(q, t, (texto, pct) => setProgreso({ texto, pct })));
      await onGuardar({ ...registro, resultado });
    } catch (err) { setError(err instanceof Error ? err.message : 'No se pudo analizar la entrevista.'); }
    finally { setProgreso(null); }
  };

  const encabezado = (
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap', alignItems: 'flex-start' }}>
      <div>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 700 }}>{cand?.name || 'Candidato'}</h2>
        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', flexWrap: 'wrap', marginTop: '0.2rem' }}>
          <StageBadge stage={app.stage} size="sm" />
          <span style={ayuda}>CV #{app.embeddingMatch?.ranking ?? '—'} · {puntajeCv(app)?.toFixed(0) ?? '—'} pts</span>
          <PortalTag fuente={cand?.source} />
          <button type="button" className="entrevistas-link focus-ring" onClick={onPerfil}>Ver perfil</button>
        </div>
      </div>
      {registro && <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
        <label className="ui-button ui-button-ghost focus-ring entrevistas-archivo"><Video size={14} />Cambiar video
          <input type="file" accept={VIDEO} hidden onChange={(ev) => { const f = ev.target.files?.[0]; if (f) void guardarVideo(f, f.name); ev.target.value = ''; }} /></label>
        {desactualizado && <Button size="sm" variant="secondary" icon={<RefreshCw size={14} />} disabled={!!progreso} onClick={() => void analizar(false)}>Recalcular con los requisitos actuales</Button>}
        <Button size="sm" variant="primary" icon={<Mic size={15} />} disabled={!!progreso} onClick={() => void analizar(true)}>{e ? 'Transcribir de nuevo' : 'Transcribir y analizar'}</Button>
      </div>}
    </div>
  );

  return (
    <section style={{ ...card, gap: '1rem' }} aria-label={`Entrevista de ${cand?.name || 'candidato'}`}>
      {encabezado}
      {progreso && <div role="status" style={{ display: 'grid', gap: '0.35rem' }}>
        <span style={{ fontSize: '0.84rem' }}>{progreso.texto}</span>
        <div className="entrevistas-barra"><div style={{ width: progreso.pct === null ? '35%' : `${Math.max(3, progreso.pct)}%` }} className={progreso.pct === null ? 'indeterminada' : undefined} /></div>
      </div>}
      {error && <p role="alert" style={{ color: 'var(--status-failed-text)', fontSize: '0.86rem' }}>{error}</p>}

      {!registro || !url ? (
        <div className="entrevistas-subir">
          <UploadCloud size={28} style={{ color: 'var(--primary-red)' }} />
          <p style={{ fontWeight: 600 }}>Sube el video de la entrevista</p>
          <p style={ayuda}>MP4, WebM, MOV o solo audio. Se guarda en este navegador: no se sube a ningún servidor.</p>
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', justifyContent: 'center' }}>
            <label className="ui-button ui-button-primary focus-ring entrevistas-archivo"><UploadCloud size={15} />Elegir archivo
              <input type="file" accept={VIDEO} hidden onChange={(ev) => { const f = ev.target.files?.[0]; if (f) void guardarVideo(f, f.name); ev.target.value = ''; }} /></label>
            <select className="focus-ring" defaultValue="" disabled={!!progreso} onChange={(ev) => { if (ev.target.value) void usarEjemplo(ev.target.value); ev.target.value = ''; }}
              style={{ padding: '0.45rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-default)', background: 'var(--bg-surface)', color: 'var(--text-primary)' }}>
              <option value="">Usar un video de ejemplo…</option>
              {EJEMPLOS.map((x) => <option key={x.archivo} value={x.archivo}>{x.nombre}</option>)}
            </select>
          </div>
        </div>
      ) : (
        <div className="entrevistas-panel">
          <div style={{ display: 'grid', gap: '0.75rem', alignContent: 'start', minWidth: 0 }}>
            {esAudio ? <audio ref={video as unknown as React.RefObject<HTMLAudioElement>} src={url} controls style={{ width: '100%' }} onTimeUpdate={(ev) => setTiempo(ev.currentTarget.currentTime)} />
              : <video ref={video} className="entrevistas-video" src={url} controls onTimeUpdate={(ev) => setTiempo(ev.currentTarget.currentTime)}>
                {vtt && <track kind="subtitles" srcLang="es" label="Español" src={vtt} default />}
              </video>}
            <p style={ayuda}>{registro.archivo}</p>
            {e && <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.5rem', marginBottom: '0.35rem' }}>
                <h3 style={{ fontSize: '0.9rem', fontWeight: 700 }}>Transcripción</h3>
                <span style={ayuda}>{e.transcripcion.modelo} · {e.transcripcion.dispositivo}</span>
              </div>
              <div className="entrevistas-transcripcion">
                {e.transcripcion.segmentos.map((s, i) => (
                  <button key={i} type="button" className={tiempo >= s.inicio && tiempo < s.fin ? 'actual' : undefined} onClick={() => ir(s.inicio)}>
                    <span className="entrevistas-tiempo">{mmss(s.inicio)}</span><span>{s.texto}</span>
                  </button>
                ))}
              </div>
            </div>}
          </div>
          {e ? <Analisis resultado={e} ir={ir} /> : <div style={{ display: 'grid', placeItems: 'center', textAlign: 'center', gap: '0.5rem', padding: '1.5rem' }}>
            <Mic size={32} style={{ color: 'var(--text-muted)' }} />
            <p style={{ fontWeight: 600 }}>Entrevista sin analizar</p>
            <p style={ayuda}>«Transcribir y analizar» convierte el audio en texto con Whisper y lo compara con los requisitos del aviso.
              La primera vez el navegador descarga el modelo; después queda guardado.</p>
          </div>}
        </div>
      )}
    </section>
  );
}

function Barra({ valor }: { valor: number }) {
  return <div className="entrevistas-barra"><div style={{ width: `${Math.max(2, Math.min(100, valor))}%` }} /></div>;
}

function Analisis({ resultado: e, ir }: { resultado: NonNullable<RegistroEntrevista['resultado']>; ir: (t: number) => void }) {
  const m = e.metricas;
  return (
    <div style={{ display: 'grid', gap: '1rem', alignContent: 'start', minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.9rem' }}>
        <span className="entrevistas-puntaje">{e.puntaje.toFixed(0)}</span>
        <span style={ayuda}>Puntaje de la entrevista (0-100)<br />{Math.round(PESOS.contenido * 100)} % contenido · {Math.round(PESOS.fluidez * 100)} % fluidez · {Math.round(PESOS.claridad * 100)} % claridad</span>
      </div>
      <div className="entrevistas-sub">
        <div><span>Contenido</span><strong>{e.contenido.toFixed(0)}</strong><span>responde a los requisitos</span></div>
        <div><span>Fluidez</span><strong>{e.fluidez.toFixed(0)}</strong><span>{m.ppm.toFixed(0)} palabras/min · {m.pausasLargas} pausas largas</span></div>
        <div><span>Claridad</span><strong>{e.claridad.toFixed(0)}</strong><span>{m.muletillasTotal} muletillas · {m.repeticiones} repeticiones</span></div>
      </div>
      <div>
        <h3 style={{ fontSize: '0.9rem', fontWeight: 700, marginBottom: '0.5rem' }}>Evidencia por requisito</h3>
        <div style={{ display: 'grid', gap: '0.7rem' }}>
          {e.porRequisito.map((p) => (
            <div key={p.requisito} style={{ display: 'grid', gap: '0.3rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.5rem', alignItems: 'flex-start' }}>
                <strong style={{ fontSize: '0.83rem' }}>{p.requisito}</strong>
                {p.puntaje >= UMBRAL_SUSTENTO ? <Badge size="sm" variant="success">Sustentado</Badge> : p.negacion ? <Badge size="sm" variant="danger">Lo niega</Badge> : <Badge size="sm">Débil</Badge>}
              </div>
              <Barra valor={p.puntaje} />
              <div style={{ display: 'flex', gap: '0.4rem', alignItems: 'baseline' }}>
                <button type="button" className="entrevistas-tiempo focus-ring" onClick={() => ir(p.inicio)}><Play size={11} /> {mmss(p.inicio)}</button>
                <q style={{ ...ayuda, fontStyle: 'italic' }}>{p.evidencia}</q>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div>
        <h3 style={{ fontSize: '0.9rem', fontWeight: 700, marginBottom: '0.35rem' }}>Observaciones</h3>
        <ul style={{ paddingLeft: '1.1rem', display: 'grid', gap: '0.25rem', fontSize: '0.83rem' }}>{e.observaciones.map((o) => <li key={o}>{o}</li>)}</ul>
      </div>
      <p style={ayuda}>Solo se analiza lo que la persona dice y cómo lo dice. No se evalúan rostro, gestos, apariencia, la voz como rasgo personal ni emociones.
        {!e.transcripcion.tiemposPorPalabra && ' Los tiempos por palabra son estimados en este navegador.'}</p>
    </div>
  );
}

function RankingFinal({ filas, pesoCv, onPeso, onVer }: { filas: Fila[]; pesoCv: number; onPeso: (v: number) => void; onVer: (appId: string) => void }) {
  const conEntrevista = filas.filter((f) => f.registro?.resultado).map((f) => {
    const cv = puntajeCv(f.app);
    const ent = f.registro!.resultado!.puntaje;
    return { ...f, cv, ent, final: cv === null ? ent : (cv * pesoCv + ent * (100 - pesoCv)) / 100 };
  }).sort((a, b) => b.final - a.final);

  return (
    <section style={{ ...card, marginTop: '1rem' }} aria-label="Ranking final CV más entrevista">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '1rem', flexWrap: 'wrap' }}>
        <h2 style={{ fontSize: '0.95rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem' }}><Trophy size={18} />Ranking final: CV + entrevista</h2>
        <label style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', fontSize: '0.82rem', color: 'var(--text-secondary)', flexWrap: 'wrap' }}>
          <span>CV <strong style={{ color: 'var(--text-primary)' }}>{pesoCv} %</strong></span>
          <input type="range" min={0} max={100} step={5} value={pesoCv} onChange={(ev) => onPeso(Number(ev.target.value))} aria-label="Peso del CV en el puntaje final" style={{ accentColor: 'var(--primary-red)' }} />
          <span>Entrevista <strong style={{ color: 'var(--text-primary)' }}>{100 - pesoCv} %</strong></span>
        </label>
      </div>
      {!conEntrevista.length ? <p style={ayuda}>Cuando analices al menos una entrevista, aquí aparece el ranking que combina el puntaje del CV con el de la entrevista.</p> : (
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
            <thead><tr style={{ textAlign: 'left', color: 'var(--text-secondary)' }}>
              <th style={{ padding: '0.5rem' }}>#</th><th style={{ padding: '0.5rem' }}>Candidato</th>
              <th style={{ padding: '0.5rem', textAlign: 'right' }}>CV</th><th style={{ padding: '0.5rem', textAlign: 'right' }}>Entrevista</th>
              <th style={{ padding: '0.5rem', textAlign: 'right' }}>Final</th><th />
            </tr></thead>
            <tbody>{conEntrevista.map((f, i) => (
              <tr key={f.app.id} style={{ borderTop: '1px solid var(--border-subtle)' }}>
                <td style={{ padding: '0.5rem', fontWeight: 700 }}>{i + 1}</td>
                <td style={{ padding: '0.5rem' }}><strong>{f.cand?.name}</strong> <PortalTag fuente={f.cand?.source} /></td>
                <td style={{ padding: '0.5rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{f.cv === null ? '—' : f.cv.toFixed(0)}</td>
                <td style={{ padding: '0.5rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{f.ent.toFixed(0)}</td>
                <td style={{ padding: '0.5rem', textAlign: 'right', fontWeight: 700, fontVariantNumeric: 'tabular-nums', color: 'var(--primary-red)' }}>{f.final.toFixed(0)}</td>
                <td style={{ padding: '0.5rem', textAlign: 'right' }}><Button size="sm" variant="ghost" onClick={() => onVer(f.app.id)}>Ver entrevista</Button></td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      )}
    </section>
  );
}
