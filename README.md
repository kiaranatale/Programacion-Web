# Programación Web

Repositorio del proyecto de la cursada de Programación Web (ITBA): el
**SGA**, un rediseño del Sistema de Gestión Académica del ITBA hecho con
Next.js, Supabase y Mercado Pago.

**Sitio publicado: https://itbasga.vercel.app**

Usuarios de prueba (personas ficticias), todos con la contraseña `123456`:

| Rol | Mail |
|---|---|
| Alumna | `alumno.demo@itba.edu.ar` |
| Docente | `docente.demo@itba.edu.ar` |
| Administración | `admin.demo@itba.edu.ar` |

### Cómo probar el pago con Mercado Pago

La app usa la cuenta de prueba de Mercado Pago (no se mueve plata real).

1. Entrar como `alumno.demo@itba.edu.ar` e ir a **Legajos → Mi legajo →
   Estado de cuenta**.
2. En una factura impaga, tocar **Ver detalle y pagar** y después
   **Pagar $ … con Mercado Pago**.
3. En Mercado Pago, ingresar con el usuario comprador de prueba:
   - Usuario: `TESTUSER1041472329563522996`
   - Contraseña: `OZHtpq8wwy`
4. Pagar con la tarjeta de prueba:
   - Mastercard `5031 7557 3453 0604`
   - Código de seguridad: `123`
   - Vencimiento: `11/30`
5. Al volver al SGA, la factura figura como pagada (la confirma el webhook
   de Mercado Pago).

## Estructura

```text
sga/            # Proyecto SGA: app, base de datos, scripts y tests (ver sga/README.md)
```

- [sga/README.md](sga/README.md): qué hace, cómo está armado y cómo
  levantarlo.
- [sga/ROADMAP.md](sga/ROADMAP.md): estado de cada pantalla y lo que queda.
