using Domain.Interfaces;
using Domain.Models.Accounting;
using Dapper;
using System.Data;
using System.Data.SqlClient;
using System.Collections.Generic;
using System.Linq;

namespace Infrastructure.Data.Dapper
{
    public class ChargeRepository : IChargeRepository
    {
        private readonly string connectionString;
        public ChargeRepository(string connectionString){
            this.connectionString = connectionString;
        }

        public long Add(Charge charge)
        {
            throw new System.NotImplementedException();
        }

        public void Delete(Charge charge)
        {
            throw new System.NotImplementedException();
        }

        public void Dispose()
        {
            throw new System.NotImplementedException();
        }

        public Charge Get(long id)
        {
            using (IDbConnection db = new SqlConnection(connectionString)){
                string chargeSQL = @"SELECT * FROM CHARGES WHERE id = @id";
                Charge charge = db.QueryFirstOrDefault<Charge>(chargeSQL, new{ id});
                return charge;
            }
        }

        public IQueryable<Charge> GetList()
        {
            throw new System.NotImplementedException();
        }

        public void Update(Charge charge)
        {
            throw new System.NotImplementedException();
        }
    }
}