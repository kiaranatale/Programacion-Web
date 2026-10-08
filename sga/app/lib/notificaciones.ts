// Pantalla donde se ve el detalle de cada tipo de notificación. Al
// entrar ahí, las de ese tipo quedan leídas.
export const destinoNotificacion: Record<string, string> = {
  TRAMITE: "/tramites",
  DOCUMENTACION: "/legajo/alumno/documentacion",
  INTERCAMBIO: "/intercambios",
  FACTURA: "/legajo/estado-de-cuenta",
  AUSENCIA: "/legajo/alumno/calendario",
};
