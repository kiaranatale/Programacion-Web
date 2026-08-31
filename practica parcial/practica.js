/* Necesito...	Método probable
Agregar al final	        push()
Buscar un elemento	        ind()
Buscar una posición	        findIndex()
Quitar un elemento	        splice()
Filtrar y devolver varios	filter()
Transformar cada elemento	map()
Contar o acumular	        reduce()
Ordenar una copia	        sort()
 */

let libros = [];
let idCounter = 0;

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
    renderizarLibros();
    return nuevoLibro;
}

function eliminarLibro(id, libros) {
    const indice = libros.findIndex(libro => libro.id === id);
    if (indice !== -1){
    libros.splice(indice,1)
    }
    renderizarLibros();
}

function marcarComoLeido(id,libros){
    const libro = libros.find(libro => libro.id === id);
    if (libro){
        libro.leido=true
    }
    renderizarLibros();
}

function obtenerLibros (libros){
    return libros
}

function filtrarPorGenero (genero, libros){
    return libros.filter(libro => libro.genero === genero)
}

function obtenerEstadisticas (libros){
    const total = libros.length;

    const leido = libros.filter(libro => libro.leido===true)
    const leidos = leido.length

    const noLeido = libros.filter(libro => libro.leido===false)
    const noLeidos = noLeido.length

    return {
        total,
        leidos, 
        noLeidos
    };
}

function buscarLibros(termino, libros){
    return libros.filter(libro => 
        libro.titulo.toLowerCase().includes(termino.toLowerCase()) || libro.autor.toLowerCase().includes(termino.toLowerCase())
    )
}

function filtrarPorRangoDeAños(añoInicio, añoFin, libros){
    return libros.filter(libro =>
        libro.año >= añoInicio && libro.año <= añoFin
    );
}

function ordenarLibros(criterio, ascendente, libros){
    const copia = [...libros]

    copia.sort((libroA, libroB) => {
        let resultado;
        
        if (criterio.toLowerCase() === "año"){
            resultado = libroA[criterio] - libroB[criterio] 
        } else {
            resultado = libroA[criterio].localeCompare(libroB[criterio])
        }

        return ascendente ? resultado : -resultado
    });

    return copia;

}

function agruparPorGenero(){
    return libros.reduce((grupos, libro) => {
        const genero = libro.genero;

        if (!grupos[genero]) {
            grupos[genero] = [];
        }

        grupos[genero].push(libro);

        return grupos;
    }, {});
}

/* 
3) Cómo te sirve pensar así en el futuro
Cuando te enfrentes a un ejercicio parecido, hacelo en este orden:

¿Qué estructura tengo?
arreglo de objetos

¿Qué recibe la función?
un texto, un número, un ID, un arreglo

¿Qué devuelve?
arreglo, objeto, número, booleano

¿Qué método aplica?
push, find, findIndex, filter, sort, reduce

¿Modifica el arreglo original?
--> si sí, es una operación en el estado
--> si no, devuelve una copia o un resultado nuevo

4) Regla práctica que te va a salvar
- Si la función debe devolver varios elementos, casi siempre es filter().

- Si la función debe encontrar un único elemento, casi siempre es find() o findIndex().

- Si la función debe contar o resumir, suele ser length, reduce() o filter().length.

- Si la función debe ordenar, casi siempre es sort() sobre una copia. */


function renderizarLibros() {
    const lista = document.getElementById("lista-libros");
    lista.innerHTML = "";

    libros.forEach(libro => {
        const li = document.createElement("li");
        li.textContent = `${libro.titulo} - ${libro.autor} (${libro.año}) - ${libro.genero} - ${libro.leido ? "Leído" : "No leído"}`;
        lista.appendChild(li);
    });
}

libros.push(
    { id: idCounter++, titulo: "1984", autor: "George Orwell", año: 1949, genero: "Distopía", leido: false },
    { id: idCounter++, titulo: "El Hobbit", autor: "J.R.R. Tolkien", año: 1937, genero: "Fantasía", leido: true }
);

renderizarLibros();

document.getElementById("form-libro").addEventListener("submit", (e) => {
    e.preventDefault();

    const titulo = document.getElementById("titulo").value.trim();
    const autor = document.getElementById("autor").value.trim();
    const año = Number(document.getElementById("año").value);
    const genero = document.getElementById("genero").value.trim();
    const leido = document.getElementById("leido").checked;

    if (!titulo || !autor || !genero || !año) return;

    agregarLibro(titulo, autor, año, genero, leido, libros);

    e.target.reset();
    renderizarLibros();
});