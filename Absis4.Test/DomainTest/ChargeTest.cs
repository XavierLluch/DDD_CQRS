using System;
using Xunit;
using Domain.Models.Accounting; 
using Domain.Models.Structure; 
using Domain.Builders;
using Domain;

namespace DomainTest
{
    public class ChargeTest
    {
        [Fact]
        /// <summary>
        /// Creem un càrrec en mèmoria
        /// </summary>
        public void TestBuildCharge()
        {
            Account accountToTest = new Account();
            BillableConcept billableConceptToTest = new BillableConcept();
            long userIdToTest = 789;

            Charge c = new ChargeBuilder(userIdToTest,DateTime.Now)
                .To(accountToTest)
                .From(billableConceptToTest)
                .WithDate(DateTime.Now)
                .With(new decimal(123.456))
                .AddDescription("ChargeToTest")
                .WithWorkFlowState(666)
                .Build();

            Assert.IsType<Charge>(c);
        }

        [Fact]
        /// <summary>
        /// Controla que en crear-se un càrrec es té informat el centre de cost
        /// </summary>
        public void TestNotAccountIdInBuildChargeThrowException()
        {
            Exception ex = Assert.Throws<DomainException>(() => new ChargeBuilder(-1,DateTime.Now).Build());         
            Assert.Equal("No se ha asignado un CENTRO al cargo.",ex.Message);
        }

        [Fact]
        /// <summary>
        /// Controla que en crear-se un càrrec es té informat el concepte facturable
        /// </summary>
        public void TestNotBCIdInBuildChargeThrowException()
        {
            Exception ex = Assert.Throws<DomainException>(() => new ChargeBuilder(-1,DateTime.Now).To(new Account()).Build());         
            Assert.Equal("No se ha asignado un CONCEPTO FACTURABLE al cargo.",ex.Message);         
        }

        [Fact]
        /// <summary>
        /// Controla que en crear-se un càrrec es té informada la quantitat en €
        /// </summary>
        public void TestNotAmountInBuildChargeThrowException()
        {
            Exception ex = Assert.Throws<DomainException>(() => new ChargeBuilder(-1,DateTime.Now)
                .To(new Account()).From(new BillableConcept()).Build());         
            Assert.Equal("No se ha asignado una CANTIDAD de € al cargo.",ex.Message);       
        }

        [Fact]
        /// <summary>
        /// Controla que en crear-se un càrrec es té informada la Data Valor
        /// </summary>
        public void TestNotValueDateInBuildChargeThrowException()
        {
            Exception ex = Assert.Throws<DomainException>(() => new ChargeBuilder(-1,DateTime.Now)
                .To(new Account()).From(new BillableConcept()).With(666m).Build());         
            Assert.Equal("No se ha asignado una FECHA VALOR al cargo.",ex.Message);       
        }

        [Fact]
        /// <summary>
        /// Controla que en crear-se un càrrec es té informat el workflow_state del càrrec
        /// </summary>
        public void TestNotWorkFlowStateInBuildChargeThrowException()
        {
            Exception ex = Assert.Throws<DomainException>(() => new ChargeBuilder(-1,DateTime.Now)
                .To(new Account()).From(new BillableConcept()).With(666m).WithDate(DateTime.Now).Build());         
            Assert.Equal("No se ha indicado un ESTADO DEL FLUJO DE TRABAJO (workflow_state) al cargo.",ex.Message);       
        }
    }
}
