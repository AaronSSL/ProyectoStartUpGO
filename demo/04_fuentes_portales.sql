-- =============================================================================================
-- CV UP · 04 Portal de origen de cada postulante (Bumeran, LinkedIn o Computrabajo) para la demo de Integraciones.
-- Solo hace falta si cargaste los 02 antes de que existiera este archivo: los 02 nuevos ya traen la columna «Fuente».
-- Misma regla que demo/generar_demo.py (portal_de): 55 % Bumeran, 25 % LinkedIn y 20 % Computrabajo según la clave.
-- Se puede correr las veces que quieras.
-- =============================================================================================
update public.postulaciones
set datos_json = datos_json || jsonb_build_object('Fuente',
      case when ('x' || substr(md5(clave), 1, 7))::bit(28)::int % 20 < 11 then 'Bumeran'
           when ('x' || substr(md5(clave), 1, 7))::bit(28)::int % 20 < 16 then 'LinkedIn'
           else 'Computrabajo' end);

select datos_json ->> 'Fuente' as portal, count(*) as postulantes
from public.postulaciones group by 1 order by 2 desc;
