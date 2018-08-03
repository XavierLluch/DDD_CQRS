using System;
using System.Linq;
using Domain.Interfaces;
using Domain.Models.Accounting;

namespace Application.Services
{
    public class UnitsService
    {
        IUnitRepository unitRepository;

        public UnitsService(IUnitRepository unitRepository)
        {
            this.unitRepository = unitRepository;
        }

        public IQueryable<Unit> GetAllUnits(){
            return unitRepository.GetList();
        }
    }
}