let edad=33
let nombre="Estaban"
//let se usa para definir variables que pueden cambiar su valor a lo largo del tiempo. En este caso, hemos definido dos variables: "edad" con un valor de 33 y "nombre" con un valor de "Esteban".
let profesor = true
let PI = 3.14 // En JavaScript el decimal se representa con un punto (.) y no con una coma (,). Por lo tanto, el valor de PI es 3.14 y no 3,14.
console.log ("Hola mundo") // Devuelve "Hola mundo"
console.log (edad + 1) // Devuelve 34
// console.log cumple la misma funcion que el print en python.
console.log (nombre + 1) // Devuelve "Esteban1" ya que al sumar un número a una cadena de texto, el número se convierte en una cadena y se concatena con la cadena original.
console.log (nombre - 1) // Devuelve NaN (Not a Number) ya que no se puede restar un número a una cadena de texto.
console.log (nombre * 2) // Devuelve NaN (Not a Number) ya que no se puede multiplicar una cadena de texto por un número.
console.log (nombre / 2) // Devuelve NaN (Not a Number) ya que no se puede dividir una cadena de texto por un número. 
console.log (1 + 1) // Devuelve 2
console.log ("1" + 1) // Devuelve "11" ya que al sumar un número a una cadena de texto, el número se convierte en una cadena y se concatena con la cadena original.
console.log ("2" - 1) // Devuelve 1 ya que al restar un número a una cadena de texto, la cadena se convierte en un número y se realiza la operación.
console.log ("perro" && "gato") // Devuelve "gato" ya que el operador && devuelve el segundo operando si el primero es verdadero.
console.log ("perro" || "gato") // Devuelve "perro" ya que el operador || devuelve el primer operando si es verdadero.
console.log (10>5) // Devuelve true ya que 10 es mayor que 5.
console.log (10<5) // Devuelve false ya que 10 no es menor que 5.
console.log (10==10) // Devuelve true ya que 10 es igual a 10.
console.log (10=="10") // Devuelve true ya que 10 es igual a "10" ya que el operador == convierte el tipo de dato de los operandos antes de compararlos.
console.log (10==="10") // Devuelve false ya que 10 no es estrictamente igual a "10".
console.log (10!=10) // Devuelve false ya que 10 no es diferente de 10.
console.log (10!==10) // Devuelve false ya que 10 no es estrictamente diferente de 10.
console.log (10===10) // Devuelve true ya que 10 es estrictamente igual a 10.

//arrays (listas) A diferencia de las listas de python, los arrays empiezan en 0, no en 1. Por lo tanto, el primer elemento de un array es el elemento 0 y no el elemento 1.
let frutas = ["manzana", "banana", "cereza"]
console.log (frutas[0]) // Devuelve "manzana"
console.log (frutas[1]) // Devuelve "banana"
console.log (frutas[2]) // Devuelve "cereza"
frutas[0] = "pera" // Cambia el valor del primer elemento del array a "pera"
console.log (frutas[0]) // Devuelve "pera"
frutas.push("naranja") // Agrega un nuevo elemento al final del array
console.log (frutas) // Devuelve ["pera", "banana", "cereza", "naranja"]
frutas.pop() // Elimina el último elemento del array
console.log (frutas) // Devuelve ["pera", "banana", "cereza"]
frutas.shift() // Elimina el primer elemento del array
console.log (frutas) // Devuelve ["banana", "cereza"]
frutas.splice(1, 1) // Elimina el segundo elemento del array
console.log (frutas) // Devuelve ["banana"]
frutas.unshift("kiwi") // Agrega un nuevo elemento al principio del array
console.log (frutas) // Devuelve ["kiwi", "banana"]
// una lista puede servir para un carrito de compras


//diccionarios (objetos) A diferencia de los diccionarios de python, los objetos de javascript no tienen un método para obtener las claves y los valores. Sin embargo, se puede acceder a las claves y los valores de un objeto utilizando el método Object.keys() y Object.values() respectivamente.
let persona = {
    nombre: "Esteban",
    edad: 33,
    profesor: true
}
console.log (persona.nombre) // Devuelve "Esteban"
console.log (persona.edad) // Devuelve 33
console.log (persona.profesor) // Devuelve true

console.log (Object.keys(persona)) // Devuelve ["nombre", "edad", "profesor"]
console.log (Object.values(persona)) // Devuelve ["Esteban", 33, true]

let persona2 = {
    nombre: "Juan",
    edad: 25,
    profesor: false
}
let personas = [persona, persona2] // Creamos un array de objetos
console.log (personas) // Devuelve [{nombre: "Esteban", edad: 33, profesor: true}, {nombre: "Juan", edad: 25, profesor: false}]
console.log (personas[0].nombre) // Devuelve "Esteban"
console.log (personas[1].edad) // Devuelve 25
[] + [] // Devuelve "" ya que al sumar dos arrays vacíos, el resultado es un array vacío.
[] + {} // Devuelve "[object Object]" ya que al sumar un array vacío y un objeto, el resultado es un string que representa al objeto.
{} + [] // Devuelve 0 ya que al sumar un objeto vacío y un array vacío, el resultado es 0.
{} + {} // Devuelve NaN ya que al sumar dos objetos vacíos, el resultado es NaN.

    