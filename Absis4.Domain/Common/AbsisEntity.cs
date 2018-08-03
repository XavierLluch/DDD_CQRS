using System;

namespace Domain.Models.Common
{
    public abstract class AbsisEntity : IEntity
    {
        #region Properties
        /// <summary>
        /// Data d'alta de la entitat. Serveix per identificar si la entitat està ACTIVA en det. moment del temps
        /// </summary>
        public DateTime TT_start_date {get; protected set;}

        /// <summary>
        /// Data de baixa de la entitat. Serveix per identificar si la entitat està ACTIVA en det. moment del temps
        /// </summary>
        public Nullable<DateTime> TT_end_date {get; protected set;}
        
        /// <summary>
        /// Id de l'usuari que fet l'alta de la entitat
        /// </summary>
        public long TT_start_user_id {get; protected set;}
        
        /// <summary>
        /// Id de l'usuari que ha donat de baixa la entitat
        /// </summary>
        public Nullable<long> TT_end_user {get; protected set;}

        /// <summary>
        /// Inici de la validesa de la entitat. Es fa servir per determina si una enitat és VÀLIDA en det. moment del temps
        /// </summary>
        public DateTime VT_start_date {get; protected set;}

        /// <summary>
        /// Final de la validesa de la enitat. Es fa servir per determina si una enitat és VÀLIDA en det. moment del temps
        /// </summary>
        public Nullable<DateTime> VT_end_date {get; protected set;}

        public long id {get; protected set;}

        public DateTime last_change_date {get; protected set;}

        public long last_change_user_id {get; protected set;}
        #endregion

        #region Constructors
        //Per defecte a l'aplicació -1 representa que no té identificador (ID)
        protected AbsisEntity() : this(-1){}

        protected AbsisEntity(long id){
            this.id = id;
        }
        #endregion
    
        #region Equality Test
        /// <summary>
        /// Determina si una entitat és igual a aquesta instància.
        /// </summary>
        /// <param name="entity">L'objecte que volem comparar</param>
        /// <returns>True si és igual false si ho és ;-)</returns>
        public override bool Equals(object entity){
            if(entity == null || !(entity is AbstractAbsisEntity)){
                return false;
            }
            return (this == (AbstractAbsisEntity)entity);
        }

        /// <summary>
        /// Operador sobrecarregat per detrminar igualtat
        /// </summary>
        /// <param name="base1">Primera instància a comparar</param>
        /// <param name="base2">Segona intància a comparar</param>
        /// <returns>True si SÓN iguals</returns>
        public static bool operator ==(AbstractAbsisEntity base1, AbstractAbsisEntity base2){
            if ((object)base1 == null || (object)base2 == null) return false;
            if(base1.id != base2.id) return false;
            return true;
        }

        /// <summary>
        /// Operador sobrecarregat per determinar les no igualtats
        /// </summary>
        /// <param name="base1">Primera instància a comparar</param>
        /// <param name="base2">Segona intància a comparar</param>
        /// <returns>True si NO són iguals</returns>
        public static bool operator !=(AbstractAbsisEntity base1, AbstractAbsisEntity base2){
            return (!(base1 == base2));
        }

        /// <summary>
        /// Hash function per a aquest tipus
        /// </summary>
        /// <returns>Codi hash per a la propietat id</returns>
        public override int GetHashCode(){
            return this.id.GetHashCode();
        }

        #endregion
    }
}