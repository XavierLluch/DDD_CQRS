using System.Linq;
using Domain.Interfaces;

namespace Infrastructure.Data.Dapper
{
    public class DapperRepository<TEntity> : IRepository<TEntity> where TEntity : class
    {
        protected readonly DapperContext Db;

        public DapperRepository()
        {
        }

        public long Add(TEntity entity)
        {
            throw new System.NotImplementedException();
        }

        public void Delete(TEntity entity)
        {
            throw new System.NotImplementedException();
        }

        public void Dispose()
        {
            throw new System.NotImplementedException();
        }

        public TEntity Get(long id)
        {
            throw new System.NotImplementedException();
        }

        public IQueryable<TEntity> GetList()
        {
            throw new System.NotImplementedException();
        }

        public void Update(TEntity entity)
        {
            throw new System.NotImplementedException();
        }
    }
}