-- Esquema inicial: usuarios, carreras, materias, correlatividades,
-- cursadas, inscripciones, notas y pagos.

create extension if not exists "pgcrypto";

create type rol_usuario as enum ('alumno', 'profesor', 'admin');
create type estado_inscripcion as enum ('inscripto', 'regular', 'libre', 'abandonada');
create type tipo_nota as enum ('parcial_1', 'parcial_2', 'recuperatorio', 'final');
create type concepto_pago as enum ('matricula', 'cuota');
create type estado_pago as enum ('pendiente', 'aprobado', 'rechazado');

-- Perfil público de cada usuario autenticado (1:1 con auth.users).
create table public.usuarios (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null,
  apellido text not null,
  email text not null,
  rol rol_usuario not null default 'alumno',
  created_at timestamptz not null default now()
);

create table public.carreras (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  descripcion text,
  created_at timestamptz not null default now()
);

create table public.materias (
  id uuid primary key default gen_random_uuid(),
  carrera_id uuid not null references public.carreras (id) on delete cascade,
  nombre text not null,
  codigo text not null unique,
  cuatrimestre_sugerido smallint,
  created_at timestamptz not null default now()
);

create index materias_carrera_id_idx on public.materias (carrera_id);

-- Correlatividades: para cursar `materia_id` hace falta tener aprobada
-- (o regularizada, según se valide en el flujo de inscripción) `requiere_materia_id`.
create table public.correlatividades (
  materia_id uuid not null references public.materias (id) on delete cascade,
  requiere_materia_id uuid not null references public.materias (id) on delete cascade,
  primary key (materia_id, requiere_materia_id),
  constraint correlatividad_no_self check (materia_id <> requiere_materia_id)
);

create table public.cursadas (
  id uuid primary key default gen_random_uuid(),
  materia_id uuid not null references public.materias (id) on delete cascade,
  profesor_id uuid references public.usuarios (id) on delete set null,
  anio smallint not null,
  cuatrimestre smallint not null check (cuatrimestre in (1, 2)),
  cupo integer,
  created_at timestamptz not null default now(),
  unique (materia_id, anio, cuatrimestre)
);

create index cursadas_profesor_id_idx on public.cursadas (profesor_id);
create index cursadas_materia_id_idx on public.cursadas (materia_id);

create table public.inscripciones_cursada (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.usuarios (id) on delete cascade,
  cursada_id uuid not null references public.cursadas (id) on delete cascade,
  estado estado_inscripcion not null default 'inscripto',
  created_at timestamptz not null default now(),
  unique (alumno_id, cursada_id)
);

create index inscripciones_alumno_id_idx on public.inscripciones_cursada (alumno_id);
create index inscripciones_cursada_id_idx on public.inscripciones_cursada (cursada_id);

create table public.notas (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.usuarios (id) on delete cascade,
  cursada_id uuid not null references public.cursadas (id) on delete cascade,
  tipo tipo_nota not null,
  valor numeric(4, 2) not null check (valor >= 0 and valor <= 10),
  created_at timestamptz not null default now(),
  unique (alumno_id, cursada_id, tipo)
);

create index notas_alumno_id_idx on public.notas (alumno_id);
create index notas_cursada_id_idx on public.notas (cursada_id);

create table public.pagos (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.usuarios (id) on delete cascade,
  concepto concepto_pago not null,
  monto numeric(10, 2) not null check (monto > 0),
  estado estado_pago not null default 'pendiente',
  mercadopago_payment_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index pagos_alumno_id_idx on public.pagos (alumno_id);

-- Mantiene `updated_at` al día en cada UPDATE.
create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger pagos_set_updated_at
  before update on public.pagos
  for each row
  execute function public.set_updated_at();
