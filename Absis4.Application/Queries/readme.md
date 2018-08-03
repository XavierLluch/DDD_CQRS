#Queries segon patró CQRS

- Les queries No modifiquen mai la base de dades o les entitats de negoci estiguin enmagatzemades on sigui.
- Les queries retornen DTOs
- Els DTOs NO encapsuleb cap coneixement de negoci que no siguin les dades del propi DTO.

![Alt text](../DocImgs/CQRS Patró.png?raw=true "Patró CQRS - Command Query Responsability Segregation")
Model bàsic CQRS

![Alt text](../DocImgs/CQRS Logica.png?raw=true "Lógica de treball amb el Patró CQRS")
Logica del model CQRS entre client i BBDD

## Patró Materialized View 
Es tracta únicament que convertir en Views aquelles consultes que requereixen de varies entitats de la BBDD de forma que es simplifica el DTO ja que no té necessitat d'estar format per diferents objectesrelatius a diferents entitats de la BBDD sinó que, en fer servir la View, pot mapejar les columnes d'aquesta en properties simples directament (P.ex si una entitat necessita pel seu DTO un objecte Enterprise per preguntar pel seu nom, fent servir aquest partó es pot crear una taula d'aquesta entitat que contingui una columna amb el camp name de la entitat enterprise)

NOTES:
 * ExportExcel segueix el patró Materialized View
 * Les consultes bàsiques d'entitats fan servir el petró Materialized View
