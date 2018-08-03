using System;
using System.Text;
using Domain.Builders;
using Domain.Models;
using Domain.Models.Common;
using Domain.Models.Structure;

namespace Domain.Models.Accounting
{
    public class Charge : AbstractAbsisEntity
    {
        public Account clientAccount {get; protected set;}
        public BillableConcept billableConcept {get; protected set;}
        public string description {get; protected set;}
        public decimal amount {get; protected set;}
        public DateTime value_date {get; protected set;}
        public int workflow_state {get; protected set;}
        public long last_change_user {get; protected set;}

        public Charge(ChargeBuilder builder){
            this.id = builder.id;
            this.clientAccount = builder.clientAccount;        
            this.billableConcept = builder.billableConcept;     
            this.amount = builder.amount;     
            this.description = builder.description;     
            this.value_date = builder.value_date;     
            this.workflow_state = builder.workflow_state;     
            this.last_change_user = builder.last_change_user;
            this.last_change_date = builder.last_change_date;          
        }

        public string ToString(){
            return String.Format("ChargeId:{0} AccountId:{1} BillableConceptId:{2} Amount:{3} ValueDate{4}",
                id,clientAccount.id,billableConcept.id,amount,value_date);           
        }

        ///TODO:
        //Afegir les funcions que siguin especifiques del càrrec a nivell de domini. P.ex si la fem que sigui una
        //AggregateRoot amb info de descomptes i consums... hauriem d'implementar els mètodes per a que ens doni
        //el seu consum i si li han aplicat descomptes p.ex.

        //Si afegim info consum i tarifes hauriem d'afegir una funció d'autoupdate del amount a partir del nou consum 
        //o la nova tarifa
    }
}

/*[id],[account_id],[billable_concept_id],[charge_type_id],[description],[amount]
,[is_invoiced],[value_date],[invoice_date],[register_date],[is_sent_to_jde],[scope_id]
,[workflow_state],[last_change_date],[last_change_user],[invoice_date_planned],[budgetary_code] */