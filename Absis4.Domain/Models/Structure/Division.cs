using System;
using Domain.Builders;
using Domain.Models.Common;

namespace Domain.Models.Structure
{
    public class Division : AbstractAbsisEntity
    {
        /* Propietats temporals (requereixen de versionats) */
        public string code {get; protected set;}
        public string name {get; protected set;}

        public Division(DivisionBuilder builder){

        }
    }
}