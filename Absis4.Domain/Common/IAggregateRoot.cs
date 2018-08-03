namespace Absis4.Domain.Common
{
    public interface IAggregateRoot : IAggregate
    {
         long Version {get;}
    }
}