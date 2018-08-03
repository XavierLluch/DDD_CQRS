## **ViewModels o Models de la Capa Aplicació**

- En aquest espai de directori s'agrupen els ViewModels o DTOs (Data Transfer Object) que fem servir per transmetre les dades de consulta (Queries) als usuaris o altres apps que reclamen info. 

- Els ViewModels no son estrictament contenidors de dades per una vista client en concret (com la definició de MVC) ni els DTOs són els clàssics objectes de negoci amb els que es fan operacions d'escriptura. En aquest cas les classes SON SEMPRE contenidors de dades per accions de consulta (Queries); MAI per accions d'escriptura. I poden es transmetre a una vista client, o a un servei o a un procés. 

