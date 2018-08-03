namespace Absis4.Application.Queries.Structure
{
    public interface IDivisionQueries
    {
         Task<DivisionDTO> Get(long id);

         Task<List<DivisionDTO>> GetAll();
    }
}