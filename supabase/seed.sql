-- Datos de ejemplo para desarrollo. No se ejecuta automáticamente:
-- correlo a mano desde el SQL Editor de Supabase cuando quieras tener
-- carreras/materias de prueba.

insert into public.carreras (nombre, descripcion) values
  ('Ingeniería Informática', 'Carrera de grado en informática'),
  ('Licenciatura en Análisis de Sistemas', 'Carrera de grado en sistemas')
on conflict (nombre) do nothing;

with carrera as (
  select id from public.carreras where nombre = 'Ingeniería Informática'
)
insert into public.materias (carrera_id, nombre, codigo, cuatrimestre_sugerido)
select carrera.id, m.nombre, m.codigo, m.cuatrimestre_sugerido
from carrera, (values
  ('Álgebra', 'ALG101', 1),
  ('Análisis Matemático I', 'MAT101', 1),
  ('Programación', 'PRG101', 1),
  ('Análisis Matemático II', 'MAT201', 2),
  ('Estructuras de Datos', 'PRG201', 2),
  ('Programación Web', 'PRG301', 3)
) as m (nombre, codigo, cuatrimestre_sugerido)
on conflict (codigo) do nothing;

-- Correlatividades de ejemplo: para cursar "Análisis Matemático II" y
-- "Estructuras de Datos" hace falta tener aprobadas sus predecesoras.
insert into public.correlatividades (materia_id, requiere_materia_id)
select req.id, base.id
from public.materias req, public.materias base
where (req.codigo, base.codigo) in (
  ('MAT201', 'MAT101'),
  ('PRG201', 'PRG101'),
  ('PRG301', 'PRG201')
)
on conflict do nothing;
