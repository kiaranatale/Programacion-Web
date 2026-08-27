// Contador global para generar ids únicos, similar a un autoincremental de base de datos.
let idCounter = 0;

// Ejercicio 1: CRUD básico

function agregarLibro(titulo, autor, año, genero, leido = false, libros) {
    const nuevoLibro = {
        id: idCounter++,
        titulo,
        autor,
        año,
        genero,
        leido
    };
    libros.push(nuevoLibro);
    return nuevoLibro;
}

function eliminarLibro(id, libros) {
    const indice = libros.findIndex(libro => libro.id === id);
    if (indice !== -1) {
        libros.splice(indice, 1);
    }
}

function marcarComoLeido(id, libros) {
    const libro = libros.find(libro => libro.id === id);
    if (libro) {
        libro.leido = true;
    }
}

function obtenerLibros(libros) {
    return libros;
}

function filtrarPorGenero(genero, libros) {
    const resultado = [];
    for (let libro of libros) {
        if (libro.genero === genero) {
            resultado.push(libro);
        }
    }
    return resultado;
}

function obtenerEstadisticas(libros) {
    let leidos = 0;
    let noLeidos = 0;

    for (let libro of libros) {
        if (libro.leido) {
            leidos++;
        } else {
            noLeidos++;
        }
    }

    return {
        total: libros.length,
        leidos,
        noLeidos
    };
}

// Ejercicio 2: búsqueda y filtros avanzados

function buscarLibros(termino, libros) {
    const terminoNormalizado = termino.toLowerCase();
    return libros.filter(libro =>
        libro.titulo.toLowerCase().includes(terminoNormalizado) ||
        libro.autor.toLowerCase().includes(terminoNormalizado)
    );
}

function filtrarPorRangoDeAños(añoInicio, añoFin, libros) {
    return libros.filter(libro => libro.año >= añoInicio && libro.año <= añoFin);
}

function ordenarLibros(criterio, ascendente = true, libros) {
    const copia = [...libros];
    copia.sort((a, b) => {
        if (a[criterio] < b[criterio]) return ascendente ? -1 : 1;
        if (a[criterio] > b[criterio]) return ascendente ? 1 : -1;
        return 0;
    });
    return copia;
}

function agruparPorGenero(libros) {
    const grupos = {};
    for (let libro of libros) {
        if (!grupos[libro.genero]) {
            grupos[libro.genero] = [];
        }
        grupos[libro.genero].push(libro);
    }
    return grupos;
}

module.exports = {
    agregarLibro,
    eliminarLibro,
    marcarComoLeido,
    obtenerLibros,
    filtrarPorGenero,
    obtenerEstadisticas,
    buscarLibros,
    filtrarPorRangoDeAños,
    ordenarLibros,
    agruparPorGenero
};
