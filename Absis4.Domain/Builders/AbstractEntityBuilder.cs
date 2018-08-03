using System;
using Domain.Models.Common;

namespace Domain.Builders
{
    public abstract class AbstractEntityBuilder<TEntity> : IBuilder<AbstractAbsisEntity> where TEntity : AbstractAbsisEntity
    {
        #region Properties
        public long id { get; protected set; }
        public DateTime TT_start_dateTime { get; protected set; }
        public Nullable<DateTime> TT_end_dateTime{ get; protected set; }
        public long TT_start_user { get; protected set; }
        public Nullable<long> TT_end_user { get; protected set; }
        public DateTime last_change_dateTime{ get; protected set; }
        public long last_change_user_id { get; protected set; }
        #endregion

        #region Constructors
        /// <summary>
        /// Constructor per a entitats Absis noves (id == -1)
        /// </summary>
        /// <param name="last_change_user_id">id d'usuari que fa l'ultim canvi</param>
        /// <param name="last_change_dateTime">data de l'ultim canvi</param>
        public AbstractEntityBuilder(long last_change_user_id, DateTime last_change_dateTime)
        {
            this.last_change_user_id = last_change_user_id;
            this.last_change_dateTime = last_change_dateTime;
        }

        /// <summary>
        /// Constructor per a entitats Absis existents
        /// </summary>
        /// <param name="id">id de la entitat Absis</param>
        /// <param name="last_change_user_id">id d'usuari que fa l'ultim canvi</param>
        /// <param name="last_change_dateTime">data de l'ultim canvi</param>
        public AbstractEntityBuilder(long id, long last_change_user_id, DateTime last_change_dateTime)
        {
            this.last_change_user_id = last_change_user_id;
            this.last_change_dateTime = last_change_dateTime;
            this.id = id;
        }
        #endregion

        public abstract AbstractAbsisEntity Build();


    }
}