console.log ("Hola mundo");

let nombre = "prompt('Ingrese su nombre')";
let titulo = document.getElementById("titulo");

titulo.textContent = "Bienvenido " + nombre;

let botonCalcular= document.querySelector("#calcular");

console.log(botonCalcular);

botonCalcular.addEventListener("click", 
    function() {
        let textoInput = document.querySelector("#datoImportante").value
        let parrafoVacio = document.querySelector("#textoAgregar");
        parrafoVacio.textContent = textoInput;
    }
);