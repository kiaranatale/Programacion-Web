// Tipos manuales que reflejan supabase/migrations/*.sql.
// Cuando el proyecto de Supabase esté creado, se pueden regenerar con:
//   npx supabase gen types typescript --project-id <id> > src/lib/supabase/database.types.ts

export type RolUsuario = "alumno" | "profesor" | "admin";
export type EstadoInscripcion = "inscripto" | "regular" | "libre" | "abandonada";
export type TipoNota = "parcial_1" | "parcial_2" | "recuperatorio" | "final";
export type ConceptoPago = "matricula" | "cuota";
export type EstadoPago = "pendiente" | "aprobado" | "rechazado";

export interface Database {
  public: {
    Tables: {
      usuarios: {
        Row: {
          id: string;
          nombre: string;
          apellido: string;
          email: string;
          rol: RolUsuario;
          created_at: string;
        };
        Insert: {
          id: string;
          nombre: string;
          apellido: string;
          email: string;
          rol?: RolUsuario;
        };
        Update: Partial<{
          nombre: string;
          apellido: string;
          email: string;
          rol: RolUsuario;
        }>;
      };
      carreras: {
        Row: {
          id: string;
          nombre: string;
          descripcion: string | null;
          created_at: string;
        };
        Insert: {
          nombre: string;
          descripcion?: string | null;
        };
        Update: Partial<{ nombre: string; descripcion: string | null }>;
      };
      materias: {
        Row: {
          id: string;
          carrera_id: string;
          nombre: string;
          codigo: string;
          cuatrimestre_sugerido: number | null;
          created_at: string;
        };
        Insert: {
          carrera_id: string;
          nombre: string;
          codigo: string;
          cuatrimestre_sugerido?: number | null;
        };
        Update: Partial<{
          carrera_id: string;
          nombre: string;
          codigo: string;
          cuatrimestre_sugerido: number | null;
        }>;
      };
      correlatividades: {
        Row: {
          materia_id: string;
          requiere_materia_id: string;
        };
        Insert: {
          materia_id: string;
          requiere_materia_id: string;
        };
        Update: Partial<{ materia_id: string; requiere_materia_id: string }>;
      };
      cursadas: {
        Row: {
          id: string;
          materia_id: string;
          profesor_id: string | null;
          anio: number;
          cuatrimestre: number;
          cupo: number | null;
          created_at: string;
        };
        Insert: {
          materia_id: string;
          profesor_id?: string | null;
          anio: number;
          cuatrimestre: number;
          cupo?: number | null;
        };
        Update: Partial<{
          materia_id: string;
          profesor_id: string | null;
          anio: number;
          cuatrimestre: number;
          cupo: number | null;
        }>;
      };
      inscripciones_cursada: {
        Row: {
          id: string;
          alumno_id: string;
          cursada_id: string;
          estado: EstadoInscripcion;
          created_at: string;
        };
        Insert: {
          alumno_id: string;
          cursada_id: string;
          estado?: EstadoInscripcion;
        };
        Update: Partial<{ estado: EstadoInscripcion }>;
      };
      notas: {
        Row: {
          id: string;
          alumno_id: string;
          cursada_id: string;
          tipo: TipoNota;
          valor: number;
          created_at: string;
        };
        Insert: {
          alumno_id: string;
          cursada_id: string;
          tipo: TipoNota;
          valor: number;
        };
        Update: Partial<{ valor: number }>;
      };
      pagos: {
        Row: {
          id: string;
          alumno_id: string;
          concepto: ConceptoPago;
          monto: number;
          estado: EstadoPago;
          mercadopago_payment_id: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          alumno_id: string;
          concepto: ConceptoPago;
          monto: number;
          estado?: EstadoPago;
          mercadopago_payment_id?: string | null;
        };
        Update: Partial<{
          estado: EstadoPago;
          mercadopago_payment_id: string | null;
        }>;
      };
    };
  };
}
