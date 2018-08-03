using Domain.Models.Common;

namespace Domain.Models.Accounting
{
    public class BillableConcept : AbstractAbsisEntity
    {
        private Service service;
        private Concept concept;

        public Service Service { get => service; set => service = value; }
        public Concept Concept { get => concept; set => concept = value; }

    }
}