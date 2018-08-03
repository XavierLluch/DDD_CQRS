using System;
using Domain.Models.Common;
using Domain.Models.Structure;

namespace Domain.Builders
{
    public class DivisionBuilder : AbstractEntityBuilder<Division>
    {      
        /* Porpietats temporals (requereixen de versionats) */
        public string code {get; protected set;}
        public string name {get; protected set;}
        public DateTime VT_start_date {get; protected set;}
        public Nullable<DateTime> VT_end_date {get; protected set;}

        #region Constructors
        /// <summary>
        /// Constructor per a divisions noves (id == -1)
        /// </summary>
        /// <param name="last_change_user">id d'usuari que fa l'ultim canvi</param>
        /// <param name="last_change_date">data de l'ultim canvi</param>

        #endregion

        #region Builders
        /// <summary>
        /// Data d'inici de la entitat
        /// </summary>
        /// <param name="TT_start_date">Data d'inici</param>
        public DivisionBuilder From(DateTime TT_start_date)
        {
            this.TT_start_dateTime = TT_start_date;
            return this;
        }

        /// <summary>
        /// Date en que s'ha donat de baixa
        /// </summary>
        /// <param name="TT_end_date">Data de baixa</param>
        public DivisionBuilder Until(DateTime TT_end_date)
        {
            this.TT_end_dateTime = TT_end_date;
            return this;
        }

        #endregion

        public override Division Build()
        {
            throw new NotImplementedException();
        }
    }
}