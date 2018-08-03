# ABSIS4 amb Clean Architecture 

Absis4 es basa en la filosofia o arquitectura d'aplicacions "Clean Architecture". Pots trobar més info a https://8thlight.com/blog/uncle-bob/2012/08/13/the-clean-architecture.html. Utilitza el patró CQRS amb Events per a la gestió de la
informació entre la BBDD i les interfícies d'usuari - altres serveis.


Per a crear aquest tipus d'arquitectura el projecte es separa en capes on 
![Clean Architecture Diagram by Uncle Bob](https://8thlight.com/blog/assets/posts/2012-08-13-the-clean-architecture/CleanArchitecture-8d1fe066e8f7fa9c7d8e84c1a6b0e2b74b2c670ff8052828f4a7e73fcbbc698c.jpg)

*Clean Architecture Diagram by Uncle Bob*

1. Domain: Enterprise Business Rules (Entities)
1. Application: Application Business Rules (Use Cases)
3. Infrastructure: Interface Adapters, Frameworks & Drivers
4. Web: Web Interfaces
5. Test


##Algunes definicions a tenir en compte al llarg del projecte són:

###Capes
**Capa Web o de Presentació (Presentation):** aquí agrupen totes les aplicacions siguin webs, webservices o web apis. També aquelles aplicacions o codi de presentació d'informació. Té dues responsabilitats aquesta capa: 
    1. Interpretar les peticions dels usuaris / sistemes i enviar aquesta petició a la capa d'aplicació o domini
    2. Mostrar la informació al'usuari

**Capa Aplicació (Application):** quan es parla de la capa Application es refereix a la capa on es coordinen les accions dels objectes del model de domini. No se suposa que contingui regles d'empresa o coneixement del domini, ni té la funció de mantenir l'estat (per a això és el model de domini). És útil per coordinar tasques i delegar accions al model de domini. Tot i que no s'utilitza per mantenir l'estat d'una entitat de negoci, pot controlar l'estat que rastreja les tasques en curs que realitza un usuari o el sistema. És molt important que la capa d'aplicació no interfereixi sobre el model de domini. En aquesta capa poden haver serveis que coordinen la comunicació entre capes. Considerem p.ex. un servei de de comandes. Aquest servei probablement pren el missatge d'una comanda en format XML, crida  aun facotry per transformar l' XML en un objecte i, a continuació, envia l'objecte a la capa del domini per al processament. Un cop finalitzat el procés, és possible que el servei hagi de remetre una notificació a un usuari i pot delegar-la en un servei de capa d'infraestructura.

**Capa Domini (Domain):** es refereix al domini empresarial de l'aplicació. Quines són les regles empresarials per a les entitats i procesos sense tenir en compte la BBDD o el seu model de dades. Com s'emmagatzemen les dades es delega a la capa *Infrastruture.* En aquesta capa normalment hi han Entitats, Value Objects i de vegades Services (interfaces que proveeixen d'operacions). Pel cas dels serveis, i d'acord amb l'exemple de comandes anterior, el servei de la capa de domini seria responsable d'interactuar amb els objectes Entity adequats, els Value Objects i altres objectes de la capa de domini necessaris per a processar la comanda en el domini. En última instància, el servei retornaria algun tipus de resultat de la operació perquè el servei que l'ha cridat (el servei de la capa Application) pogui prendre les accions necessàries.

**Capa Infarstructura (Infrastructure):**  aquí és on es genera i executa el codi relacionat amb aplicacions o arquitectures externes al negoci com ara els objectes de persistència a una base de dades, l'enviament de missatges, i el registre i control de comunicacions amb altres aplicacions p.ex. També pot servir com a marc arquitectònic per a les interaccions entre les quatre capes. Pel que fa als serveis d'aquesta capa, i en el mateix escenari de les comandes, el servei de capa d'infraestructures pot necessitar fer coses com ara l'enviament a un usuari d'un correu electrònic de confirmació de la comanda per a que sàpiga que la seva comanda s'està processant. Aquests tipus de les activitats pertanyen a la capa d'infraestructures. Aquesta capa "ajuda" a fer més prima o bàsica la capa Application. Per exemple la capa Application s'encarrega de saber quan s'ha d'enviar un correu, però és la capa Infrastructure la que fa l'enviament del correu.

### Contextos
**Context limitat (Bounded context):** prové d'Eric Evans. I és una forma de descompondre's un sistema gran i complex en peces més manejables; Un gran sistema està format per múltiples contextos acotats. Cada context delimitat és el context pel seu propi model de domini autònom, i té el seu propi llenguatge. També podeu veure el context limitat com un component de negoci autònom amb uns límits clarament definits: normalment un context limitat es comunica amb un altre context delimitat a través d'*esdeveniments*.

P.ex, a la nostra aplicació aquests limits de context poden ser ''Structure Context'' on engloben totes les entitats i accions que afecten a entitats d'estructura (Divisions, Empreses, Unitats Emissores, Departaments i Centres); un altre seria ''Accounting Context'' per a Serveis, Conceptes, Conceptes Facturables i Tarifes; un altre seria ''Billing Context'' per a ordres de factura, linies de factura, clients factura, split de carrecs, impostos; un altre la gestió de l'aplicació ''Aplication Management Context'' per a usuaris, permisos, procesos,... (falta veure si exports a excel, pel focus,... són un altre context).

**Mapa de contexte (Context Map):** segons Eric Evans, hauríeu de "Descriure els punts de contacte entre els models, esbossar la traducció explícita per a qualsevol comunicació i destacar qualsevol intercanvi ". Aquest exercici es tradueix en el que s'anomena mapa de context, que té diversos propòsits que inclouen proporcionar una visió general de tot el sistema i ajudar a la gent a entendre els detalls de com diferents contextes acotats interactuen entre si.


##Algunes definicions al patró CQRS i ES (Event Sourcing):

**Entitat (Entity):** la entitat de domini és un objecte que es definieix bàsicament per la seva identitat (id). De vegades alguns objectes que pensem que són entitats en un sistema no ho són en un altre. *P.exe el cas de les adreces. Un sistema les pot tractar com atributs associats a una persona o empresa (sense ID) i en un altre com p.ex una aplicació sobre els impostos dels ajuntaments és una entitat (amb ID propi).*

**Objecte Valor (Value Object):** Els objectes valor a direfernecia de les entitats NO tenen identitat (id). Normalment només contenen valors o un comportament. Són els que es defineix molt sovint com a DTOs (Datya Transfer Objects). És molt comú que una entitat contingui objectes valors, inclús que un objecte valor contigui un altre objecte valor. Es recomaqna que sigui immutable, es a dir, que es creei des de u constructor i que les seves propietats siguin read-only.

**Ordre (Command):** És una petició per a què el sistema realitzi una acció que canvia l'estat del sistema. Les odres són imperatives;
*MakeSeatReservation* és un exemple. En aquest context limitat, les ordres s'originen des de la interfície d'usuari com a resultat de una sol·licitud per part d'un usuari o d'un gestor de processos quan el gestor de processos està dirigint un agregat per a realitzar una acció.
Un sol destinatari és qui processa una ordre. Un transportador d'ordres (command bus) transporta les ordres al registrador d'ordres (command handler) i aquests les envien als agregats. Enviar una ordre és una operació asíncrona sense retorn valor.

**Esdeveniment (Event):** Un esdeveniment, com *OrderConfirmed*, descriu alguna cosa que ha passat en el sistema, normalment com a resultat d'una ordre. Els agregats al model de domini generen esdeveniments.
Múltiples subscriptors poden gestionar un esdeveniment específic. Els agregats publiquen esdeveniments a un bus d'esdeveniments; Els registradors (handlers) registren per a tipus específics de esdeveniments al bus de l'esdeveniment i després lliuren l'esdeveniment a un subscriptor. En aquest context limitat, l'únic subscriptor és un gestor de processos.

**Gestor de Processos (Process manager):** En aquest context limitat, un *gestor de processos* és una classe que coordina el comportament dels agregats en el domini. Un administrador de processos es subscriu als esdeveniments que generen els agregats,
i llavors segueix un senzill conjunt de regles per determinar quina ordre o ordres ha d'enviar. El gestor de processos no conté lògica d'empresa; simplement conté lògica per determinar el següent comandament a enviar. El gestor de processos s'implementa com a una màquina d'estats, per tant quan respon a un esdeveniment, pot canviar el seu estat intern per enviar un nova odre.
Aquest gestor de processos en aquest context pot rebre ordres i subscriures a events.

**Aggregates (agregats):** un Aggregate és un terme utilitzat per definir la pertinença a un objecte i els límits entre objectes i les seves relacions. S'utilitza per definir a un grup d'objectes associats que es poden tractar com una unitat pel que fa als canvis de dades. Per exemple, una clase Order i els seus associats, les línies de comanda, es poden considerar part del mateix Agregat de comanda, amb la clase Order com a arrel de l'Agregat (root aggregate). Això porta a recordar una norma molt important: "cada Agregat només pot tenir un objecte root i aquest objecte és un objecte Entity". L'arrel d'un Agregat pot contenir referències a les arrels d'altres Agregats i poden contenir referències entre si, però res fora del límit Agregat pot accedir als objectes de l'Agregat sense passar
per aquest objecte root. És més fàcil d'entendre aquest concepte amb un exemple:
    Un objecte Order és el root del seu propi agregat, i conté objectes com ara elements de línia (que pot contenir productes) i clients. Per aconseguir arribar a un objecte Element_de_línia, hauria de passar per l'objecte root de l'Agregat, l'objecte Order. Si només volia obtenir algunes dades sobre un client i no de l' ordre, podria optar per començar des de l'Agregat Client. Podria passar de l'Agregat Order a l'Agregat Client, ja que l'Agregat Order conté una instància d'un client. D'altra banda, podria arribar a l'ordre del client passant per l'Agregat Client primer, i després recórrer la relació entre un client i les seves ordres. En aquest cas, la relació és bidireccional i podria optar per començar des de l'Agregat Client o des de l'Argregat Order, depenent del cas d'ús. La clau per recordar és que tant el client com l'ordre són les arrels del seu propi Agregat, i també pot contenir referències a altres roots agregades. 
Definir els agregats en un model de domini és una de les activitats més difícils d'aconseguir i necessitarem una constant refactorització a mida que es coneix el negoci.