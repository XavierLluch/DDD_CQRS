using System;
using Domain.Models.Accounting;
using Domain.Models.Common;

namespace Domain.Interfaces
{
    public interface IWriteUnitRepository : IWriteRepository<AbstractAbsisEntity>
    {
        //Extensió de la interfaç bàsica de CRUD ... en aquest cas un exemple d'altres mètodes CRUD
        //que pot necessitar el model de domini
        Unit GetBySymbol(string unitSymbol);     
    }
}