using Domain.Models.Common;

namespace Domain.Models.Accounting
{
    public class Unit : AbstractAbsisEntity
    {
        public string name { get; private set; }
        public string symbol { get; private set; }
        public bool consumable { get; private set; }

        public Unit(long id, string name, string symbol, bool consumable) 
        {
            this.id = id;
            this.name = name;
            this.symbol = symbol;
            this.consumable = consumable;    
        }
    }
}