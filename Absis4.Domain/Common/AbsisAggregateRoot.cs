namespace Absis4.Domain.Common
{
    public class AbsisAggregateRoot : AbsisEntity, IAggregateRoot
    {
        private readonly Dictionary<Type, Action<object>> handlers = new Dictionary<Type, Action<object>>();
        private readonly List<IDomainEvent> domainEvents = new List<IDomainEvent>();

        public AbsisAggregateRoot(){

        }

    }
}