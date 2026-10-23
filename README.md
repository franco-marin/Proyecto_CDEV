# Bosque Hambriento

Juego 3D hecho con **Godot 4.7**. Sos un yaguareté en la selva paranaense: en cada nivel
tenés que cazar y comer 3 presas (tapires, pecaríes, corzuelas, carpinchos, osos
hormigueros, ocelotes o yacarés) sin morir de hambre y sin que te atrape un cazador.
Primero hay que abatirlas a zarpazos y después comerlas. La maleza te esconde y el río
—que cruzás nadando— es una vía de escape, porque los cazadores no lo cruzan.

Se puede jugar en tercera persona (click derecho para moverse y cazar) o en primera
persona (WASD + mouse, click izquierdo para el zarpazo y E para comer).

## Niveles

El mapa se genera al azar en cada partida, siempre con un río.

| Nivel | Selva | Peligros |
|-------|-------|----------|
| 1: Selva intacta | Mucha maleza y animales, río celeste | Yacarés en el río |
| 2: Selva amenazada | Menos maleza y animales, río verdoso | 2 cazadores, basura (te enferma si pasás a menos de 1 m) |
| 3: Selva degradada | Poca maleza y pocos animales, río sucio | 5 cazadores, más basura y trampas (10 s sin poder correr) |

## Cómo abrirlo

1. Descargar Godot 4.7 desde [godotengine.org](https://godotengine.org).
2. En el Administrador de Proyectos: **Importar** → elegir `project.godot`.
3. **F5** para jugar.

## Flujo de trabajo con ramas

| Rama   | Para qué es                                           |
|--------|-------------------------------------------------------|
| `main` | Producto final, versión estable.                      |
| `dev`  | Desarrollo: acá se juntan los cambios nuevos.         |
| otras  | Una rama por cambio, creada a partir de `dev`.        |

Para hacer un cambio:

```bash
git checkout dev
git pull
git checkout -b nombre-del-cambio
# ... hacer los cambios ...
git add .
git commit -m "Descripción del cambio"
git push -u origin nombre-del-cambio
```

Después, en GitHub, abrir un **pull request** de `nombre-del-cambio` hacia `dev`.
Cuando `dev` esté listo para una versión final, se abre un pull request de `dev` hacia `main`.
