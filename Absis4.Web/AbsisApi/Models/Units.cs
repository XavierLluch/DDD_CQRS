using System;
using System.Collections.Generic;
using Domain.Models.Accounting;

namespace AbsisApi.Models
{
    public static class Units
    {
        public static List<Unit> GetUnits()
        {
            var p = new List<Unit>(){
                new Unit(5298,"x 100 Páginas","x 100",true),
                new Unit(5301,"Horas","Horas",true),
                new Unit(5302,"Páginas","Págs.",true),
                new Unit(5305,"X 100 MegaBytes","x 100",true),
                new Unit(5309,"Metros Cuadr.","M2",true),
            };

            return p;
        }
    }
}