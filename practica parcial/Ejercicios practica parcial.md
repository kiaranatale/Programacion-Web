# **Ejercicios de Práctica CRUD \- Gestión de Biblioteca Personal**

[**Ejercicios de Práctica CRUD \- Gestión de Biblioteca Personal	1**](#ejercicios-de-práctica-crud---gestión-de-biblioteca-personal)

[Ejercicio 1: CRUD Básico de Libros	1](#ejercicio-1:-crud-básico-de-libros)

[Contexto y Consigna	1](#contexto-y-consigna)

[Funciones JavaScript a implementar:	1](#funciones-javascript-a-implementar:)

[Tests unitarios para el Ejercicio 1:	2](#tests-unitarios-para-el-ejercicio-1:)

[Ejercicio 2: Búsqueda y Filtros Avanzados	4](#ejercicio-2:-búsqueda-y-filtros-avanzados)

[Contexto y Consigna	4](#contexto-y-consigna-1)

[Funciones JavaScript adicionales:	4](#funciones-javascript-adicionales:)

[Tests unitarios para el Ejercicio 2:	4](#tests-unitarios-para-el-ejercicio-2:)

[Cómo ejecutar los tests	6](#cómo-ejecutar-los-tests)

---

## **Ejercicio 1: CRUD Básico de Libros**

### **Contexto y Consigna**

Eres el desarrollador de una aplicación para gestionar una biblioteca personal. Debes implementar un sistema CRUD (Crear, Leer, Actualizar, Eliminar) para libros. Cada libro tendrá: título, autor, año de publicación y género.

La aplicación debe permitir:

* Agregar nuevos libros

* Mostrar todos los libros en una lista

* Marcar libros como leídos/no leídos

* Eliminar libros existentes

* Filtrar libros por género

### **Funciones JavaScript a implementar:**

function **agregarLibro**(titulo, autor, año, genero, leido \= false) {}

function **eliminarLibro**(id) {}

function **marcarComoLeido**(id) {}

function **obtenerLibros**() {}

function **filtrarPorGenero**(genero) {}

function **obtenerEstadisticas**() {}

### **Tests unitarios para el Ejercicio 1:**

describe('Gestión de Biblioteca Personal', () \=\> {

    let libros;

    beforeEach(() \=\> {

        libros \= \[\];

        if (typeof window \!== 'undefined') {

            window.idCounter \= 0;

        }

    });

    test('Debería agregar un libro correctamente', () \=\> {

        agregarLibro('Cien años de soledad', 'Gabriel García Márquez', 1967, 'Realismo mágico', false, libros);

        expect(libros).toHaveLength(1);

        expect(libros\[0\].titulo).toBe('Cien años de soledad');

        expect(libros\[0\].leido).toBe(false);

    });

    test('Debería eliminar un libro existente', () \=\> {

        agregarLibro('El principito', 'Antoine de Saint-Exupéry', 1943, 'Fábula', true, libros);

        eliminarLibro(libros\[0\].id, libros);

        expect(libros).toHaveLength(0);

    });

    test('Debería marcar un libro como leído', () \=\> {

        agregarLibro('1984', 'George Orwell', 1949, 'Ciencia ficción', false, libros);

        marcarComoLeido(libros\[0\].id, libros);

        expect(libros\[0\].leido).toBe(true);

    });

    test('Debería filtrar libros por género', () \=\> {

        agregarLibro('Fundación', 'Isaac Asimov', 1951, 'Ciencia ficción', false, libros);

        agregarLibro('Orgullo y prejuicio', 'Jane Austen', 1813, 'Romance', true, libros);

        

        const librosCienciaFiccion \= filtrarPorGenero('Ciencia ficción', libros);

        expect(librosCienciaFiccion).toHaveLength(1);

        expect(librosCienciaFiccion\[0\].titulo).toBe('Fundación');

    });

    test('Debería generar estadísticas correctamente', () \=\> {

        agregarLibro('El hobbit', 'J.R.R. Tolkien', 1937, 'Fantasía', true, libros);

        agregarLibro('It', 'Stephen King', 1986, 'Terror', false, libros);

        

        const stats \= obtenerEstadisticas(libros);

        expect(stats.total).toBe(2);

        expect(stats.leidos).toBe(1);

        expect(stats.noLeidos).toBe(1);

    });

});

---

## **Ejercicio 2: Búsqueda y Filtros Avanzados**

### **Contexto y Consigna**

Amplía la aplicación anterior con funcionalidades de búsqueda y filtrado avanzado. Los usuarios deben poder:

* Buscar libros por título o autor

* Filtrar por rango de años

* Ordenar libros por título, año o autor

* Agrupar libros por género

### **Funciones JavaScript adicionales:**

function **buscarLibros**(termino) {}

function **filtrarPorRangoDeAños**(añoInicio, añoFin) {}

function **ordenarLibros**(criterio, ascendente \= true) {}

function **agruparPorGenero**() {}

### **Tests unitarios para el Ejercicio 2:**

describe('Búsqueda y Filtros Avanzados', () \=\> {

    let libros;

    beforeEach(() \=\> {

        libros \= \[\];

        agregarLibro('Cien años de soledad', 'Gabriel García Márquez', 1967, 'Realismo mágico', true, libros);

        agregarLibro('1984', 'George Orwell', 1949, 'Distopía', false, libros);

        agregarLibro('El señor de los anillos', 'J.R.R. Tolkien', 1954, 'Fantasía', true, libros);

    });

    test('Debería buscar libros por título', () \=\> {

        const resultados \= buscarLibros('años', libros);

        expect(resultados).toHaveLength(1);

        expect(resultados\[0\].titulo).toBe('Cien años de soledad');

    });

    test('Debería buscar libros por autor', () \=\> {

        const resultados \= buscarLibros('Tolkien', libros);

        expect(resultados).toHaveLength(1);

        expect(resultados\[0\].titulo).toBe('El señor de los anillos');

    });

    test('Debería filtrar por rango de años', () \=\> {

        const resultados \= filtrarPorRangoDeAños(1950, 1970, libros);

        expect(resultados).toHaveLength(2); // 1967 y 1954

    });

    test('Debería ordenar libros por título', () \=\> {

        const ordenados \= ordenarLibros('titulo', true, libros);

        expect(ordenados\[0\].titulo).toBe('1984');

        expect(ordenados\[1\].titulo).toBe('Cien años de soledad');

        expect(ordenados\[2\].titulo).toBe('El señor de los anillos');

    });

    test('Debería ordenar libros por año descendente', () \=\> {

        const ordenados \= ordenarLibros('año', false, libros);

        expect(ordenados\[0\].año).toBe(1967);

        expect(ordenados\[1\].año).toBe(1954);

        expect(ordenados\[2\].año).toBe(1949);

    });

});

---

## **Cómo ejecutar los tests**

1. Instala Node.js si no lo tienes.  
2. Instala Jest globalmente: **npm install \-g jest**  
3. Guarda los tests en un archivo llamado [`biblioteca.test.js`](http://biblioteca.test.js).  
4. Ejecuta los tests con:  **jest biblioteca.test.js**

