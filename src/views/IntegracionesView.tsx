import React, { useEffect, useState } from 'react';
import { AlertCircle, ArrowRight, CheckCircle2, Layers, Plug, UploadCloud } from 'lucide-react';
import { useApp } from '../context/AppContext.tsx';
import { Badge } from '../components/common/Badge.tsx';
import { Button } from '../components/common/Button.tsx';
import { supabase } from '../services/supabase.ts';
import { contarPorPortal, PORTALES, type ConteoPortales, type Portal } from '../services/portales.ts';
import { fechaHora, timeAgo } from '../services/bumeranSync.ts';

const card: React.CSSProperties = {
  backgroundColor: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)',
  padding: '1.1rem 1.25rem', display: 'flex', flexDirection: 'column', gap: '0.75rem', minWidth: 0,
};
const titulo: React.CSSProperties = { fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-primary)' };
const ayuda: React.CSSProperties = { fontSize: '0.8rem', color: 'var(--text-secondary)' };
const num = (n: number) => n.toLocaleString('es-PE');

function Sigla({ portal, grande = false }: { portal: (typeof PORTALES)[number]; grande?: boolean }) {
  const lado = grande ? '40px' : '28px';
  return <span aria-hidden="true" style={{ width: lado, height: lado, borderRadius: 'var(--radius-md)', backgroundColor: portal.color, color: '#fff',
    display: 'grid', placeItems: 'center', fontWeight: 800, fontSize: grande ? '1.05rem' : '0.8rem', flexShrink: 0 }}>{portal.sigla}</span>;
}

/** Integraciones: de qué bolsas de trabajo llegan los postulantes y cómo se consolidan en CV UP. */
export function IntegracionesView() {
  const { appState, setActiveJobPostingId, setCurrentView } = useApp();
  const [conteo, setConteo] = useState<ConteoPortales | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!supabase) return;
    let vivo = true;
    contarPorPortal(supabase).then((c) => vivo && setConteo(c)).catch((e: Error) => vivo && setError(e.message));
    return () => { vivo = false; };
  }, []);

  const avisos = appState.jobPostings.filter((job) => job.bumeran).sort((a, b) => a.title.localeCompare(b.title));
  const total = conteo ? Object.values(conteo.total).reduce((s, n) => s + n, 0) : 0;
  const ultima = avisos.map((job) => job.bumeran!.updatedAt).filter(Boolean).sort().at(-1) || null;
  const avisosDe = (p: Portal) => avisos.filter((job) => (conteo?.porAviso[job.bumeran!.avisoId]?.[p] || 0) > 0).length;
  const abrir = (jobId: string) => { setActiveJobPostingId(jobId); setCurrentView('mejores_candidatos'); };

  return (
    <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap', marginBottom: '1.5rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
          <div style={{ width: '42px', height: '42px', borderRadius: 'var(--radius-md)', backgroundColor: 'var(--primary-red-subtle)',
            color: 'var(--primary-red)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Plug size={22} />
          </div>
          <div>
            <h1 style={{ fontSize: '1.35rem', fontWeight: 700, color: 'var(--text-primary)' }}>Integraciones</h1>
            <p style={{ fontSize: '0.84rem', color: 'var(--text-secondary)' }}>
              CV UP trae a los postulantes de las bolsas de trabajo donde publicas tus avisos y los consolida en una sola base,
              con un solo ranking por aviso. Nadie tiene que descargar ni copiar CV a mano.
            </p>
          </div>
        </div>
        <Button variant="ghost" icon={<UploadCloud size={16} />} onClick={() => setCurrentView('agregar_archivos')}
          title="Cargar postulantes desde un CSV o Excel (casos excepcionales, fuera de los portales)">
          Importar desde archivo
        </Button>
      </div>

      {!supabase && <p role="status" className="import-card">Esta instalación no está conectada a la base de datos: las integraciones no están disponibles.</p>}
      {error && <div role="alert" style={{ ...card, flexDirection: 'row', alignItems: 'center', gap: '0.6rem', borderColor: 'var(--status-failed-border)', marginBottom: '1rem' }}>
        <AlertCircle size={18} style={{ color: 'var(--status-failed-text)', flexShrink: 0 }} /><span style={{ fontSize: '0.86rem' }}>{error}</span>
      </div>}

      {/* Un portal por tarjeta */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem', marginBottom: '1rem' }}>
        {PORTALES.map((p) => {
          const n = conteo?.total[p.id] ?? 0;
          return (
            <section key={p.id} style={card} aria-label={`Integración con ${p.nombre}`}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.5rem', flexWrap: 'wrap' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}><Sigla portal={p} grande /><h2 style={{ ...titulo, fontSize: '1.05rem' }}>{p.nombre}</h2></div>
                <Badge size="sm" variant="success" icon={<CheckCircle2 size={12} />}>Conectada</Badge>
              </div>
              <p style={ayuda}>{p.detalle}</p>
              <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap' }}>
                <div><p style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)', fontVariantNumeric: 'tabular-nums' }}>{conteo ? num(n) : '…'}</p>
                  <p style={ayuda}>postulantes{conteo && total ? ` · ${Math.round((100 * n) / total)} %` : ''}</p></div>
                <div><p style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)', fontVariantNumeric: 'tabular-nums' }}>{conteo ? avisosDe(p.id) : '…'}</p>
                  <p style={ayuda}>avisos con postulantes</p></div>
              </div>
              {conteo && total > 0 && <div aria-hidden="true" style={{ height: '6px', borderRadius: 'var(--radius-full)', backgroundColor: 'var(--bg-muted)', overflow: 'hidden' }}>
                <div style={{ width: `${(100 * n) / total}%`, height: '100%', backgroundColor: p.color }} />
              </div>}
              <p style={ayuda}>Última sincronización: {ultima ? `${fechaHora(ultima)} (${timeAgo(ultima)})` : '—'}</p>
            </section>
          );
        })}
      </div>

      {/* Cómo se consolida */}
      <section style={{ ...card, marginBottom: '1rem' }} aria-label="Cómo se consolidan los postulantes">
        <h2 style={{ ...titulo, display: 'flex', alignItems: 'center', gap: '0.5rem' }}><Layers size={18} />Todo se consolida en CV UP</h2>
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.45rem' }}>
            {PORTALES.map((p) => <span key={p.id} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.86rem', fontWeight: 600 }}><Sigla portal={p} />{p.nombre}</span>)}
          </div>
          <ArrowRight size={22} style={{ color: 'var(--text-muted)' }} aria-hidden="true" />
          <div style={{ flex: '1 1 260px', padding: '0.85rem 1rem', borderRadius: 'var(--radius-md)', border: '1px solid var(--primary-red-border)', backgroundColor: 'var(--primary-red-subtle)' }}>
            <p style={{ fontWeight: 700, color: 'var(--text-primary)' }}>{conteo ? `${num(total)} postulantes en una sola base` : 'Una sola base de postulantes'}</p>
            <p style={ayuda}>Mismo formato para todos, sin duplicados entre portales. Cada aviso tiene un solo ranking con IA, sin importar de dónde llegó cada persona.</p>
          </div>
          <ArrowRight size={22} style={{ color: 'var(--text-muted)' }} aria-hidden="true" />
          <ol style={{ flex: '1 1 220px', margin: 0, paddingLeft: '1.1rem', fontSize: '0.84rem', color: 'var(--text-primary)', display: 'grid', gap: '0.25rem' }}>
            <li>Ranking de CV por requisitos</li>
            <li>Entrevista en video analizada</li>
            <li>Base centralizada para futuros procesos</li>
          </ol>
        </div>
      </section>

      {/* Por aviso */}
      {avisos.length > 0 && <section style={card} aria-label="Postulantes por aviso y portal">
        <h2 style={titulo}>Postulantes por aviso</h2>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.84rem' }}>
            <thead><tr style={{ textAlign: 'left', color: 'var(--text-secondary)' }}>
              <th style={{ padding: '0.5rem' }}>Aviso</th>
              {PORTALES.map((p) => <th key={p.id} style={{ padding: '0.5rem', textAlign: 'right' }}>{p.nombre}</th>)}
              <th style={{ padding: '0.5rem', textAlign: 'right' }}>Total</th><th />
            </tr></thead>
            <tbody>{avisos.map((job) => {
              const c = conteo?.porAviso[job.bumeran!.avisoId];
              const suma = c ? c.bumeran + c.linkedin + c.computrabajo : 0;
              return <tr key={job.id} style={{ borderTop: '1px solid var(--border-subtle)' }}>
                <td style={{ padding: '0.5rem', fontWeight: 600 }}>{job.title}</td>
                {PORTALES.map((p) => <td key={p.id} style={{ padding: '0.5rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{c ? c[p.id] : '…'}</td>)}
                <td style={{ padding: '0.5rem', textAlign: 'right', fontWeight: 700, fontVariantNumeric: 'tabular-nums' }}>{c ? suma : '…'}</td>
                <td style={{ padding: '0.5rem', textAlign: 'right' }}><Button size="sm" variant="ghost" onClick={() => abrir(job.id)}>Ver ranking</Button></td>
              </tr>;
            })}</tbody>
          </table>
        </div>
      </section>}

      <p style={{ ...ayuda, marginTop: '1rem' }}>
        Cada conexión se configura con la cuenta de empresa de la organización en ese portal y según sus condiciones de uso.
        Bumeran, LinkedIn y Computrabajo son marcas de sus respectivos dueños.
      </p>
    </div>
  );
}
