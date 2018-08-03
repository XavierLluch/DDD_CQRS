using System;
using System.Collections.Generic;
using Domain.Models.Accounting;
using Domain.Models.Common;

namespace Domain.Interfaces
{
    public interface IChargeRepository : IWriteRepository<AbstractAbsisEntity>
    {
        /* Mètodes especificats a la calse base IRepository 
        Charge Get(long id);
        List<Charge> GetList();
        long Add(Charge charge);
        void Update(Charge charge);
        void Delete(Charge charge);         
        */

        /**** Aquí es poden afegir altres mètodes com ara GetByAccountClient()...o qualssevol altre
        query que volguem afegir a les clàssiques ***/
    }
}