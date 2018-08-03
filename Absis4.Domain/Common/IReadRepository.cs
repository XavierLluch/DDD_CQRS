using System;
using System.Linq;
using Domain.Models;
using Domain.Models.Common;

namespace Absis4.Domain.Common
{
    public interface IReadRepository<TEntity> : IDisposable where TEntity : AbstractAbsisEntity
    {
        TEntity Get(long id);
        IQueryable<TEntity> GetList();
    }
}