
using System;
using Domain.Interfaces;

namespace Application.Services
{
    public class ExportChargesService
    {
        IChargeRepository chargeRepository;
        public ExportChargesService(IChargeRepository chargeRepository){
            this.chargeRepository = chargeRepository;
        }   

        public void Export(){
            chargeRepository.GetList();
        }
    }
}