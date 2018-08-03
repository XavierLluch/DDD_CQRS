using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using AbsisApi.Models;
using Domain.Interfaces;
using Domain.Models.Accounting;
using Microsoft.AspNetCore.Mvc;

namespace AbsisApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ChargesController : ControllerBase
    {
        private IChargeRepository chargeRepo;
        public ChargesController(IChargeRepository chargeRepo){
            this.chargeRepo = chargeRepo;
        }
        
        /// <summary>
        /// Retorna la llista de tots els càrrecs
        /// </summary>
        /// <returns>Llista d'enumerables de càrrecs</returns>
        // GET api/values
        [HttpGet]
        public IEnumerable<Charge> Get()
        {
            return chargeRepo.GetList();
        }

        /// <summary>
        /// Retorna un càrrec
        /// </summary>
        /// <param name="id">id del càrrec a cercar</param>
        /// <returns>Objecte Càrrec</returns>
        // GET api/values/5
        [HttpGet("{id}", Name = "GetCharge")]
        public Charge Get(long id)
        {
            return chargeRepo.Get(id);
        }
    }
}