using System;
using Domain.Models.Accounting;
using Domain.Models.Structure;

namespace Domain.Builders
{
    public class ChargeBuilder : IBuilder<Charge>
    {
        public long id { get; protected set; }
        public Account clientAccount { get; protected set; }
        public BillableConcept billableConcept { get; protected set; }
        public string description { get; protected set; }
        public decimal amount { get; protected set; }
        public DateTime value_date { get; protected set; }
        public int workflow_state { get; protected set; }
        public DateTime last_change_date { get; protected set; }
        public long last_change_user { get; protected set; }

        #region Constructors
        /// <summary>
        /// Constructor per a càrrecs nous (id == -1)
        /// </summary>
        /// <param name="last_change_user">id d'usuari que fa l'ultim canvi</param>
        /// <param name="last_change_date">data de l'ultim canvi</param>
        public ChargeBuilder(long last_change_user, DateTime last_change_date)
        {
            this.last_change_user = last_change_user;
            this.last_change_date = last_change_date;
        }

        /// <summary>
        /// Constructor per a càrrecs existents
        /// </summary>
        /// <param name="id">id del càrrec</param>
        /// <param name="last_change_user">id d'usuari que fa l'ultim canvi</param>
        /// <param name="last_change_date">data de l'ultim canvi</param>
        public ChargeBuilder(long id, long last_change_user, DateTime last_change_date)
        {
            this.last_change_user = last_change_user;
            this.last_change_date = last_change_date;
            this.id = id;
        }
        #endregion

        #region Builders
        /// <summary>
        /// Centre on es carrega
        /// </summary>
        /// <param name="clientAccount">centre de cost</param>
        public ChargeBuilder To(Account clientAccount)
        {
            this.clientAccount = clientAccount;
            return this;
        }

        /// <summary>
        /// De qui i què es carrega en forma de id de Concepte Facturable.
        /// </summary>
        /// <param name="billableConcept">concepte facturable</param>
        public ChargeBuilder From(BillableConcept billableConcept)
        {
            this.billableConcept = billableConcept;
            return this;
        }

        /// <summary>
        /// Qunia quantitat es carrega (en €)
        /// </summary>
        /// <param name="amount">Quantitat a carregar</param>
        public ChargeBuilder With(decimal amount) {
          this.amount = amount;
          return this;  
        } 

        /// <summary>
        /// Amb quina Data Valor s'entra el càrrec
        /// </summary>
        /// <param name="value_date">Data valor</param>
        public ChargeBuilder WithDate(DateTime value_date){
          this.value_date = value_date;
          return this;  
        } 

        /// <summary>
        /// Indica en quin estat es troba el càrrec si ho sap (1:Inicial; 2:Facturat però obert; 3:Facturat i tancat;
        /// 4:Facturat, tancat i enviat a JDE; 5:Facturant-se; 6:Tarificant-se si provenen de consums)
        /// </summary>
        /// <param name="workflow_state">estat al fluxe de treball</param>
        public ChargeBuilder WithWorkFlowState(int workflow_state) {
          this.workflow_state = workflow_state;
          return this;  
        } 

        /// <summary>
        /// Afegeix una descripció al càrrec
        /// </summary>
        /// <param name="description">Descripció del càrrec</param>
        public ChargeBuilder AddDescription(string description) {
          this.description = description;
          return this;  
        } 
        #endregion

        public Charge Build()
        {
            //Validacions abans de tornar un objecte càrrec
            if(clientAccount == null) throw new DomainException("No se ha asignado un CENTRO al cargo.");
            if(billableConcept == null) throw new DomainException("No se ha asignado un CONCEPTO FACTURABLE al cargo.");
            if(amount < 1) throw new DomainException("No se ha asignado una CANTIDAD de € al cargo.");
            if(value_date == null) throw new DomainException("No se ha asignado una FECHA VALOR al cargo.");
            if(workflow_state < 1) throw new DomainException("No se ha indicado un ESTADO DEL FLUJO DE TRABAJO (workflow_state) al cargo.");
            
            return new Charge(this);
        }
    }
}