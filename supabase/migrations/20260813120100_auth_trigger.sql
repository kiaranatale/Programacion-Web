-- Crea automáticamente la fila en public.usuarios cuando alguien se
-- registra en Supabase Auth, y expone el rol del usuario actual para
-- usar en las políticas de RLS.

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.usuarios (id, nombre, apellido, email, rol)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', ''),
    coalesce(new.raw_user_meta_data ->> 'apellido', ''),
    new.email,
    coalesce((new.raw_user_meta_data ->> 'rol')::rol_usuario, 'alumno')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- Devuelve el rol del usuario autenticado actual. `security definer` +
-- `search_path` fijo para poder leer public.usuarios sin verse afectada
-- por las policies de RLS de esa misma tabla (evita recursión).
create function public.rol_actual()
returns rol_usuario
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.usuarios where id = auth.uid();
$$;
