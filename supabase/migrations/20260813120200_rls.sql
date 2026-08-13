-- Row Level Security: cada rol ve y modifica solo lo que le corresponde.

alter table public.usuarios enable row level security;
alter table public.carreras enable row level security;
alter table public.materias enable row level security;
alter table public.correlatividades enable row level security;
alter table public.cursadas enable row level security;
alter table public.inscripciones_cursada enable row level security;
alter table public.notas enable row level security;
alter table public.pagos enable row level security;

-- usuarios: cada uno ve/edita su propia fila; admin ve/edita todas;
-- un profesor puede ver los datos básicos de los alumnos inscriptos
-- en sus propias cursadas.
create policy "usuarios: ver propio perfil o admin" on public.usuarios
  for select
  using (
    auth.uid() = id
    or public.rol_actual() = 'admin'
    or (
      public.rol_actual() = 'profesor'
      and exists (
        select 1
        from public.inscripciones_cursada ic
        join public.cursadas c on c.id = ic.cursada_id
        where ic.alumno_id = usuarios.id
          and c.profesor_id = auth.uid()
      )
    )
  );

create policy "usuarios: editar propio perfil o admin" on public.usuarios
  for update
  using (auth.uid() = id or public.rol_actual() = 'admin');

create policy "usuarios: admin borra" on public.usuarios
  for delete
  using (public.rol_actual() = 'admin');

-- carreras / materias / correlatividades: lectura para cualquier
-- usuario autenticado, escritura solo para admin.
create policy "carreras: lectura autenticados" on public.carreras
  for select
  using (auth.uid() is not null);

create policy "carreras: solo admin escribe" on public.carreras
  for all
  using (public.rol_actual() = 'admin')
  with check (public.rol_actual() = 'admin');

create policy "materias: lectura autenticados" on public.materias
  for select
  using (auth.uid() is not null);

create policy "materias: solo admin escribe" on public.materias
  for all
  using (public.rol_actual() = 'admin')
  with check (public.rol_actual() = 'admin');

create policy "correlatividades: lectura autenticados" on public.correlatividades
  for select
  using (auth.uid() is not null);

create policy "correlatividades: solo admin escribe" on public.correlatividades
  for all
  using (public.rol_actual() = 'admin')
  with check (public.rol_actual() = 'admin');

-- cursadas: lectura para cualquier autenticado (los alumnos necesitan
-- poder explorar la oferta), escritura solo admin.
create policy "cursadas: lectura autenticados" on public.cursadas
  for select
  using (auth.uid() is not null);

create policy "cursadas: solo admin escribe" on public.cursadas
  for all
  using (public.rol_actual() = 'admin')
  with check (public.rol_actual() = 'admin');

-- inscripciones_cursada: el alumno ve/crea/borra las suyas; el profesor
-- ve las de sus propias cursadas; admin, todo.
create policy "inscripciones: alumno ve las propias" on public.inscripciones_cursada
  for select
  using (
    auth.uid() = alumno_id
    or public.rol_actual() = 'admin'
    or (
      public.rol_actual() = 'profesor'
      and cursada_id in (
        select id from public.cursadas where profesor_id = auth.uid()
      )
    )
  );

create policy "inscripciones: alumno se inscribe" on public.inscripciones_cursada
  for insert
  with check (
    (auth.uid() = alumno_id and public.rol_actual() = 'alumno')
    or public.rol_actual() = 'admin'
  );

create policy "inscripciones: alumno o admin actualiza" on public.inscripciones_cursada
  for update
  using (auth.uid() = alumno_id or public.rol_actual() = 'admin');

create policy "inscripciones: alumno o admin borra" on public.inscripciones_cursada
  for delete
  using (auth.uid() = alumno_id or public.rol_actual() = 'admin');

-- notas: el alumno ve las propias; el profesor ve/carga las de sus
-- propias cursadas; admin, todo.
create policy "notas: alumno ve las propias" on public.notas
  for select
  using (
    auth.uid() = alumno_id
    or public.rol_actual() = 'admin'
    or (
      public.rol_actual() = 'profesor'
      and cursada_id in (
        select id from public.cursadas where profesor_id = auth.uid()
      )
    )
  );

create policy "notas: profesor carga en sus cursadas" on public.notas
  for insert
  with check (
    public.rol_actual() = 'admin'
    or (
      public.rol_actual() = 'profesor'
      and cursada_id in (
        select id from public.cursadas where profesor_id = auth.uid()
      )
    )
  );

create policy "notas: profesor edita en sus cursadas" on public.notas
  for update
  using (
    public.rol_actual() = 'admin'
    or (
      public.rol_actual() = 'profesor'
      and cursada_id in (
        select id from public.cursadas where profesor_id = auth.uid()
      )
    )
  );

create policy "notas: profesor borra en sus cursadas" on public.notas
  for delete
  using (
    public.rol_actual() = 'admin'
    or (
      public.rol_actual() = 'profesor'
      and cursada_id in (
        select id from public.cursadas where profesor_id = auth.uid()
      )
    )
  );

-- pagos: el alumno ve/crea los propios; solo admin (o el service role
-- desde el webhook de Mercado Pago, que ignora RLS) puede actualizarlos.
create policy "pagos: alumno ve los propios" on public.pagos
  for select
  using (auth.uid() = alumno_id or public.rol_actual() = 'admin');

create policy "pagos: alumno crea los propios" on public.pagos
  for insert
  with check (auth.uid() = alumno_id or public.rol_actual() = 'admin');

create policy "pagos: solo admin actualiza" on public.pagos
  for update
  using (public.rol_actual() = 'admin');

create policy "pagos: solo admin borra" on public.pagos
  for delete
  using (public.rol_actual() = 'admin');
