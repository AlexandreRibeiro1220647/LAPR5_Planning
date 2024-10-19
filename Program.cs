using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authentication.Cookies;

using TodoApi.Models;
using TodoApi.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddDbContext<UserContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

    // Add HttpContextAccessor to access the current user's claim
builder.Services.AddHttpContextAccessor();

builder.Services.AddHttpClient<AuthPatientService>();
builder.Services.AddScoped<UserRegistrationService>();
builder.Services.AddScoped<AuthPatientService>();

// CORS configuration
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowLocalhost",
        builder =>
        {
            builder.AllowAnyOrigin()
                   .AllowAnyHeader()
                   .AllowAnyMethod();
        });
});

string domain = builder.Configuration["Auth0:Domain"];
string audience = builder.Configuration["Auth0:Audience"];
string clientId = builder.Configuration["Auth0:ClientId"];
string clientSecret = builder.Configuration["Auth0:ClientSecret"];


    // JWT Bearer Authentication configuration
builder.Services.AddAuthentication(options =>
{
    // Set the default authentication schemes
    options.DefaultAuthenticateScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultSignInScheme = CookieAuthenticationDefaults.AuthenticationScheme; // Set default sign-in scheme
    options.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
})
.AddCookie(options =>
{
    // Configure cookie authentication
    options.Cookie.Name = "auth_cookie";
    options.LoginPath = "/api/Patients/authenticate"; 
    options.LogoutPath = "/api/Patients/callback";
    options.Cookie.HttpOnly = true;
    options.Cookie.SameSite = SameSiteMode.None; // Allow cross-site requests
    options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest; // Use Always in production
    options.SlidingExpiration = true;
    options.ExpireTimeSpan = TimeSpan.FromHours(1); // Set the cookie expiration time

})
.AddOpenIdConnect("Auth0", options =>
{
    // Set Auth0 configuration for OpenID Connect
    options.Authority = $"https://{domain}/";
    options.ClientId = clientId;
    options.ClientSecret = clientSecret;
    options.ResponseType = "code";

    options.UsePkce = true;

    options.CallbackPath = new PathString("/api/Patients/callback");
    options.SaveTokens = true;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("email");

    options.Events = new OpenIdConnectEvents
    {
        OnAuthenticationFailed = context =>
        {
            Console.WriteLine($"Authentication failed: {context.Exception}");
            return Task.CompletedTask;
        },
        OnRedirectToIdentityProvider = context =>
        {
            context.ProtocolMessage.RedirectUri = "https://localhost:5001/api/Patients/callback";
            var stateValue = context.ProtocolMessage.State;
            Console.WriteLine($"[State] Generated and sent with the authentication request: {stateValue}");

            return Task.CompletedTask;
        },
        OnTokenValidated = context =>
        {
            Console.WriteLine("Token successfully validated.");
            return Task.CompletedTask;
        }
    };

});

// Bind Auth0 settings from appsettings.json
builder.Services.Configure<Auth0Settings>(builder.Configuration.GetSection("Auth0"));


// Add session services
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30); // Session timeout (adjust as needed)
    options.Cookie.HttpOnly = true;  // Ensure cookie is accessible only via HTTP (not JavaScript)
    options.Cookie.IsEssential = true; // Set to true to ensure session is kept even if the user hasn't consented to non-essential cookies
});

builder.Services.AddDataProtection()
    .SetApplicationName("YourApplicationName") // Optional: specify the application name
    .PersistKeysToFileSystem(new DirectoryInfo(@"./keys")); // Persist keys to the file system

// Add distributed memory cache (required for session state)
builder.Services.AddDistributedMemoryCache(); // Use this for in-memory session storage, or configure Redis/SQL if needed


// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();


var app = builder.Build();

app.UseCors("AllowLocalhost");

app.UseHttpsRedirection();

app.UseCookiePolicy();

app.UseSession();

app.UseAuthentication();
app.UseAuthorization();


// Log incoming requests for debugging
app.Use(async (context, next) =>
{
    Console.WriteLine($"Request: {context.Request.Method} {context.Request.Path}");
    await next.Invoke();
});

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}


app.MapControllers();

app.Run();
