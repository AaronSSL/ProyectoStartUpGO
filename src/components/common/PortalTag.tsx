import { datosPortal, portalDe } from '../../services/portales.ts';

/** Etiqueta pequeña con el portal de origen del postulante (Bumeran, LinkedIn o Computrabajo). */
export function PortalTag({ fuente }: { fuente: string | null | undefined }) {
  const portal = portalDe(fuente);
  if (!portal) return null;
  const p = datosPortal(portal);
  return (
    <span className="portal-tag" title={`Llegó desde ${p.nombre}`}>
      <span className="portal-tag-sigla" style={{ backgroundColor: p.color }} aria-hidden="true">{p.sigla}</span>
      {p.nombre}
    </span>
  );
}
