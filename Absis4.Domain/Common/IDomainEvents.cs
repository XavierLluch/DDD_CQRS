namespace Absis4.Domain.Common
{
    //
    // Els Events han de ser associats NOMÉS amb 1 AggregateRootId
    // Els Events han de ser serializables
    // El camp Version del Aggregat (definit a IAggregateRoot) es fa servir per al control de Transaccions en mode optimistic

    public interface IDomainEvents
    {
         
    }
}