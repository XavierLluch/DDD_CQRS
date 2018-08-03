namespace Domain.Builders
{
    public interface IBuilder<T>
    {
         T Build();
    }
}