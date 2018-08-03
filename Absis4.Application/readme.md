# Capa Aplicació (Application)

- En aquesta capa es coordinen les accions dels objectes del model de domini. 
- No conté regles d'empresa o negoci o coneixement del domini
- No té la funció de mantenir l'estat dels elements de negoci (per a això és el model de domini). 
- És útil per coordinar tasques i delegar accions al model de domini. 
- Tot i que no s'utilitza per mantenir l'estat d'una entitat de negoci, pot controlar l'estat que rastreja les tasques en curs que realitza un usuari o el sistema. 
- És molt important que la capa d'aplicació no interfereixi sobre el model de domini. 
- Poden haver serveis que coordinen la comunicació entre capes. 
- Es un bon lloc per tractar els problemes transversals de la aplicació: Transaccions, Validacions, Seguretat, ...
