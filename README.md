# Bosque Hambriento

Juego 3D hecho con **Godot 4.7**. Sos un herbívoro grande en un bosque: comé 10 frutas
sin morir de hambre y sin que te alcance un oso. Se puede jugar en tercera persona
(click derecho para moverse) o en primera persona (WASD + mouse).

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
