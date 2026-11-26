-- =============================================================================================
-- CV UP · 05 Permisos de la web (usuarios con sesión iniciada).
-- Los proyectos nuevos de Supabase ya no dan permisos automáticos sobre las tablas a los usuarios de la web; el
-- proyecto de GTH sí los tenía. Esto los replica (solo para «authenticated», nunca para visitantes sin sesión).
-- Lo que cada usuario puede ver o cambiar lo sigue limitando el RLS de cada tabla.
-- Se puede correr las veces que quieras.
-- =============================================================================================
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
