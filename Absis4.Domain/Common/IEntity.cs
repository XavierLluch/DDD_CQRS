using System;

namespace Absis4.Domain.Common
{
    public interface IEntity
    {
        /// <summary>
        /// Identificador únic a la BBDD
        /// </summary>
        long id {get;}

        /// <summary>
        /// ultima data en que s'ha realitzat un canvi a la entitat
        /// </summary>
        DateTime last_change_date {get;}

        /// <summary>
        /// Id de l'usuari que ha fet l'ultim canvi
        /// </summary>
        long last_change_user_id {get;}
    }
}