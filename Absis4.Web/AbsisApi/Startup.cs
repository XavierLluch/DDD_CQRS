using Domain.Interfaces;
using Infrastructure.Data.Dapper;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.ViewComponents;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SimpleInjector;
using SimpleInjector.Integration.AspNetCore.Mvc;
using SimpleInjector.Lifestyles;
using Swashbuckle.AspNetCore.Swagger;

namespace AbsisApi
{
    public class Startup
    {
        //Contenidor principal per a la injecció de dependència a tota l'aplicació WEB-API
        private Container container = new Container();

        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Version_2_1);

            //Configura el registre dels serveis..
            IntegrateSimpleInjector(services);

            //Afegeix el generador de Swagger (Visor mètodes de l'API)
            services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new Info { 
                    Title = "ABSIS4 API", 
                    Version = "v1",
                    Description = "API para consumo de servicios ABSIS4.",
                    Contact = new Contact{
                        Name="Xavier Lluch",
                        Email="xlluch@planeta.es"
                    } 
                });
            });
        }

        //**** Implemenetació de la injecció de dependencia per SimpleInjector ****//
        private void IntegrateSimpleInjector(IServiceCollection services)
        {
            //The recommendation is to use AsyncScopedLifestyle in for applications that solely consist of a Web API(or other asynchronous technologies such as ASP.NET Core)
            container.Options.DefaultScopedLifestyle = new AsyncScopedLifestyle();

            //*** Registre dels serveis i dbContext ***//
            //container.Register<IChargeRepository,ChargeRepository>(Lifestyle.Scoped);
            container.Register<IChargeRepository>(() => new ChargeRepository(Configuration["ConnectionStrings:AbsisConnection"]), Lifestyle.Singleton);

            //Afegim l'access a HttpContext a tota l'app
            services.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();

            //Afegim la interfaç per crear controladors
            services.AddSingleton<IControllerActivator>(new SimpleInjectorControllerActivator(container));

            //Afegim la interfaç per instanciar icrear Views
            services.AddSingleton<IViewComponentActivator>(new SimpleInjectorViewComponentActivator(container));

            //???
            services.EnableSimpleInjectorCrossWiring(container);

            //Wrap AspNet requests into Simpleinjector's scoped lifestyle
            services.UseSimpleInjectorAspNetRequestScoping(container);
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        //*** Configure es crida desprès de la crida a ConfigureServices
        public void Configure(IApplicationBuilder app, IHostingEnvironment env)
        {
            // ???
            InitializeContainer(app);

            //Add custom middleware
            //app.UseMiddleware<CustomMiddelWare1>(container);
            //app.UseMiddleware<CustomMiddelWare2>(container);

            // ???
            container.Verify();

            //*** Això ja és de l'app i no del SimpleInjection
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseHsts();
            }

            app.UseHttpsRedirection();

            //Habilitem el middleware per servir JSON de Swagger
            app.UseSwagger();

            //Habilitem el middleware per servir swagger-ui(HTML, JS, CSS, etc.)
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "ABSIS4 API V1");
            });

            app.UseMvc();
        }

        private void InitializeContainer(IApplicationBuilder app)
        {
            // Add application presentation components:
            container.RegisterMvcControllers(app);
            container.RegisterMvcViewComponents(app);

            //Add applicaction services. For instance:
            //container.Register<IUserService, UserService>(Lifestyle.Scoped);

            //Allow Simple Injector to resolve services from ASP.NET Core.
            container.AutoCrossWireAspNetComponents(app);
        }
    }
}
