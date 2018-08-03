using System;
using Domain.Models;
using Domain.Models.Common;

namespace Domain.Interfaces
{
    public interface IWriteRepository <TEntity> : IDisposable where TEntity : AbstractAbsisEntity
    {
        long Add(TEntity entity);
        void Update(TEntity entity);
        void Delete(TEntity entity); 
    }
}