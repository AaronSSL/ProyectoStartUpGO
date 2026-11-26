-- =============================================================================================
-- CV UP · 03 Cuenta de la demo.
-- 1) En Supabase: Authentication -> Users -> Add user -> Create new user, con el correo y la contraseña de la demo
--    (marca «Auto Confirm User»).
-- 2) Cambia el correo de abajo por ese mismo y corre este archivo en el SQL Editor.
-- La cuenta queda como superadministradora (ve todo, incluidos los sueldos) y sin pedir cambio de contraseña.
-- =============================================================================================
begin;
insert into public.gth_perfiles (user_id, email, nombre, nivel, debe_cambiar_clave, activo)
select id, email, 'Equipo CV UP', 'superadmin', false, true
from auth.users where email = 'demo@cvup.pe'
on conflict (user_id) do update set nivel = 'superadmin', activo = true, debe_cambiar_clave = false;

insert into public.gth_colaboradores (user_id)
select id from auth.users where email = 'demo@cvup.pe'
on conflict do nothing;

-- Debe mostrar 1 fila; si sale vacío, el correo no coincide con el usuario creado en Authentication.
select p.email, p.nivel, p.activo from public.gth_perfiles p where p.email = 'demo@cvup.pe';
commit;
