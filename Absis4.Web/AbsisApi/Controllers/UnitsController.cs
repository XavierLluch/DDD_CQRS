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
    public class UnitsController : ControllerBase
    {
        private readonly IUnitRepository unitRepository;

        public UnitsController(IUnitRepository unitRepository){
            this.unitRepository = unitRepository;
        }

        // GET api/values
        [HttpGet]
        public IEnumerable<Unit> GetAll()
        {
            return Units.GetUnits();
        }

        // GET api/values/5
        [HttpGet("{id}")]
        public Unit Get(long id)
        {
            return Units.GetUnits().FirstOrDefault(u => u.id == id);
        }

        // POST api/values
        [HttpPost]
        public void Post([FromBody] string value)
        {
        }

        // PUT api/values/5
        [HttpPut("{id}")]
        public void Put(int id, [FromBody] string value)
        {
        }

        // DELETE api/values/5
        [HttpDelete("{id}")]
        public void Delete(int id)
        {
        }
    }
}
